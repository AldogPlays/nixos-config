// SPDX-License-Identifier: MIT
#include "geometry.hpp"
#include <stdexcept>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/plugins/HookSystem.hpp>
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/helpers/Monitor.hpp>
#include <hyprland/src/managers/PointerManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>

namespace {
HANDLE owner;
CFunctionHook* motionHook = nullptr;
using Move = void (*)(CPointerManager*, const Vector2D&);
FullEdges::Box box(PHLMONITOR m) {
    return {m->m_position.x, m->m_position.y, m->m_size.x, m->m_size.y};
}
void move(CPointerManager* pointer, const Vector2D& delta) {
    auto original = reinterpret_cast<Move>(motionHook->m_original);
    if (!g_pCompositor->m_readyToProcess || g_pCompositor->m_unsafeState ||
        g_pCompositor->m_isShuttingDown || g_pInputManager->isLocked() || g_pInputManager->isConstrained()) {
        original(pointer, delta);
        return;
    }
    auto position = pointer->position();
    FullEdges::Point p{position.x, position.y};
    PHLMONITOR source;
    std::vector<FullEdges::Box> others;
    for (auto m : g_pCompositor->m_monitors) {
        if (!m->m_enabled || !m->m_dpmsStatus || m->isMirror()) continue;
        if (FullEdges::contains(box(m), p)) source = m;
        else others.push_back(box(m));
    }
    if (source && std::isfinite(delta.x) && std::isfinite(delta.y)) {
        if (auto destination = FullEdges::cross(box(source), others, p, {delta.x, delta.y})) {
            pointer->warpTo({destination->x, destination->y});
            return;
        }
    }
    original(pointer, delta);
}
}

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }
APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (std::string_view(__hyprland_api_get_hash()) != __hyprland_api_get_client_hash())
        throw std::runtime_error("full-edges: compositor ABI differs from the pinned build");
    owner = handle;
    // The API searches mangled symbols; select the exact demangled overload.
    for (const auto& match : HyprlandAPI::findFunctionsByName(handle, "CPointerManager")) {
        if (match.demangled.starts_with("CPointerManager::move(")) {
            motionHook = HyprlandAPI::createFunctionHook(handle, match.address, reinterpret_cast<void*>(&move));
            break;
        }
    }
    if (!motionHook || !motionHook->hook())
        throw std::runtime_error("full-edges: unable to hook relative pointer motion");
    return {"full-edges", "Proportional mouse crossing across entire adjacent monitor edges", "nixos-config", "1.0"};
}
APICALL EXPORT void PLUGIN_EXIT() {
    if (motionHook) HyprlandAPI::removeFunctionHook(owner, motionHook);
    motionHook = nullptr;
}

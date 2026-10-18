// Wallpaper-only adaptation of La5u/hyprmosaic, revision 7597c5ef1fc7ce7265a0117089cf88da7cd7e08f.
// Copyright (c) 2026 La5u. SPDX-License-Identifier: MIT
// Upstream LICENSE (including its Hyprland attribution) is installed with the plugin.
// No grid gestures, binary hooks, or compositor patch. Targets Hyprland 0.55.4.

#include <algorithm>
#include <charconv>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <map>
#include <stdexcept>
#include <sys/inotify.h>
#include <unistd.h>
#include <nlohmann/json.hpp>
#include <hyprgraphics/image/Image.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/debug/HyprCtl.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/helpers/Monitor.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/TexPassElement.hpp>

namespace {
struct Wallpaper {
    std::string path;
    SP<Render::ITexture> texture;
};
using Wallpapers = std::map<std::string, std::map<WORKSPACEID, Wallpaper>>;
Wallpapers walls;
std::filesystem::path session;
bool dirty = true;
int notifyFd = -1;
wl_event_source* notifySource = nullptr;
CHyprSignalListener renderListener, tickListener, workspaceListener;
SP<SHyprCtlCommand> statusCommand;
nlohmann::json lastDraws = nlohmann::json::object();
std::vector<PHLWORKSPACE> held;
UP<SEventLoopDoLaterLock> releaseLater;
cairo_user_data_key_t bmpPixelsKey;

// A strip contains at most the visible pair plus one newly requested image.
// Positions are in output widths, so adjacent tiles always share an edge.
struct Tile {
    WORKSPACEID id;
    double x;
};
struct Slide {
    WORKSPACEID active;
    double destination;
    double nativeStart;
    std::vector<Tile> start;
};
std::map<std::string, std::vector<Tile>> lastFrames;
std::map<std::string, Slide> slides;

void beginSlide(PHLWORKSPACE ws) {
    if (!ws || ws->m_isSpecialWorkspace) return;
    const auto mon = ws->m_monitor.lock();
    if (!mon) return;
    slides.erase(mon->m_name);
    // Interactive swipes/non-horizontal styles keep native positioning. On a
    // committed horizontal slide, use its curve, not a second animation clock.
    const auto offset = ws->m_renderOffset->value();
    if (!ws->m_renderOffset->isBeingAnimated() || std::abs(offset.y) > 0.01 || std::abs(offset.x) < 0.01) return;
    auto tiles = lastFrames[mon->m_name];
    std::erase_if(tiles, [](const Tile& t) { return t.x <= -1.0 || t.x >= 1.0; });
    if (tiles.empty()) return;
    auto incoming = std::ranges::find(tiles, ws->m_id, &Tile::id);
    double destination;
    if (incoming != tiles.end()) {
        destination = incoming->x; // Reverse from the pixels actually shown.
    } else {
        const auto [left, right] = std::ranges::minmax_element(tiles, {}, &Tile::x);
        destination = offset.x < 0 ? left->x - 1.0 : right->x + 1.0;
        tiles.push_back({ws->m_id, destination});
    }
    slides[mon->m_name] = {ws->m_id, destination, offset.x, std::move(tiles)};
}

void damageMonitors() {
    for (const auto& mon : g_pCompositor->m_monitors)
        g_pHyprRenderer->damageMonitor(mon);
}

void reloadImages() {
    dirty = false;
    std::ifstream input(session / "workspace-wallpapers.json");
    const auto state = nlohmann::json::parse(input, nullptr, false);
    if (state.is_discarded() || !state.is_object() || !state.contains("prepared") || !state["prepared"].is_object())
        return; // Incomplete/malformed state must not remove a working backdrop.
    Wallpapers next;
    for (const auto& [output, entries] : state["prepared"].items()) {
        if (!entries.is_object()) continue;
        for (const auto& [key, value] : entries.items()) {
            WORKSPACEID id = 0;
            const auto [end, ec] = std::from_chars(key.data(), key.data() + key.size(), id);
            if (ec != std::errc{} || end != key.data() + key.size() || id <= 0 || !value.is_string()) continue;
            const std::filesystem::path path = value.get<std::string>();
            // Only read the helper's display-sized BMPs, never arbitrary originals.
            if (path.parent_path() != session / "workspace-wallpaper-images" || path.extension() != ".bmp") continue;
            const auto oldOutput = walls.find(output);
            const Wallpaper* old = nullptr;
            if (oldOutput != walls.end()) {
                const auto it = oldOutput->second.find(id);
                if (it != oldOutput->second.end()) old = &it->second;
            }
            if (old && old->path == path.string()) {
                next[output][id] = *old;
                continue;
            }
            Hyprgraphics::CImage image(path.string());
            if (!image.success()) {
                if (old) next[output][id] = *old;
                continue;
            }
            const auto surface = image.cairoSurface();
            // Pinned hyprgraphics 0.5.1's BMP loader allocates pixels with malloc
            // but doesn't attach a destructor to its create_for_data surface.
            // All inputs here are the helper's 24-bit RGB BMPs, so give Cairo
            // ownership before this temporary decode surface is destroyed.
            if (cairo_surface_set_user_data(surface->cairo(), &bmpPixelsKey, surface->data(), std::free) != CAIRO_STATUS_SUCCESS) {
                std::free(surface->data());
                if (old) next[output][id] = *old;
                continue;
            }
            auto texture = g_pHyprRenderer->createTexture(surface->cairo());
            if (texture) {
                // That loader also inserts zero alpha. These RGB wallpapers
                // must ignore it, or repeated blending accumulates to white.
                texture->m_type = Render::TEXTURE_RGBX;
                texture->m_opaque = true;
                next[output][id] = {path.string(), texture};
            }
            else if (old) next[output][id] = *old;
        }
    }
    // As with the previous renderer, an empty collection leaves existing images alone.
    if (!next.empty()) walls = std::move(next);
}

int onNotify(int fd, uint32_t, void*) {
    alignas(inotify_event) char buffer[4096];
    ssize_t length;
    while ((length = read(fd, buffer, sizeof(buffer))) > 0) {
        for (char* p = buffer; p < buffer + length;) {
            const auto* event = reinterpret_cast<const inotify_event*>(p);
            if ((event->mask & IN_Q_OVERFLOW) || (event->len && std::string_view(event->name) == "workspace-wallpapers.json"))
                dirty = true;
            p += sizeof(inotify_event) + event->len;
        }
    }
    if (dirty) damageMonitors();
    return 0;
}

void holdMovingWorkspaces() {
    for (const auto& ref : g_pCompositor->getWorkspaces()) {
        const auto ws = ref.lock();
        if (!ws || ws->m_isSpecialWorkspace) continue;
        if ((ws->m_forceRendering || ws->m_renderOffset->isBeingAnimated()) && std::ranges::find(held, ws) == held.end())
            held.push_back(ws);
    }
}

void tick() {
    holdMovingWorkspaces();
    for (const auto& ws : held)
        if (const auto mon = ws->m_monitor.lock()) g_pHyprRenderer->damageMonitor(mon);
    // Releasing an empty workspace can destroy it: defer until outside rendering/tick iteration.
    if (!held.empty() && !releaseLater)
        releaseLater = g_pEventLoopManager->doLaterLock([] {
            std::erase_if(held, [](const auto& ws) { return !ws->m_forceRendering && !ws->m_renderOffset->isBeingAnimated(); });
            releaseLater.reset();
        });
}

void render() {
    if (dirty) reloadImages();
    holdMovingWorkspaces();
    const auto mon = g_pHyprRenderer->m_renderData.pMonitor.lock();
    if (!mon) return;
    const auto output = walls.find(mon->m_name);
    if (output == walls.end()) return;
    lastDraws[mon->m_name] = nlohmann::json::array();
    lastFrames[mon->m_name].clear();
    const Vector2D size = mon->m_transformedSize;
    const auto draw = [&](WORKSPACEID id, Vector2D origin, float alpha) {
        const auto image = output->second.find(id);
        if (image == output->second.end()) return;
        // Round the origin, never each edge independently, to avoid pixel seams.
        origin.x = std::round(origin.x);
        origin.y = std::round(origin.y);
        if (origin.x >= size.x || origin.x + size.x <= 0 || origin.y >= size.y || origin.y + size.y <= 0) return;
        CTexPassElement::SRenderData data;
        data.tex = image->second.texture;
        data.box = {origin, size};
        data.a = alpha;
        g_pHyprRenderer->m_renderPass.add(makeUnique<CTexPassElement>(std::move(data)));
        lastFrames[mon->m_name].push_back({id, origin.x / size.x});
        lastDraws[mon->m_name].push_back({{"workspace", id}, {"x", origin.x}, {"y", origin.y}, {"image", image->second.path}});
    };
    if (const auto slide = slides.find(mon->m_name); slide != slides.end()) {
        const auto active = mon->m_activeWorkspace;
        if (active && active->m_id == slide->second.active && active->m_renderOffset->isBeingAnimated()) {
            // Derive progress from the already-stepped native position, not
            // wall-clock time (which could put us a few ms ahead of windows).
            const double progress = std::clamp(1.0 - active->m_renderOffset->value().x / slide->second.nativeStart, 0.0, 1.0);
            for (const auto& tile : slide->second.start)
                draw(tile.id, {(tile.x - slide->second.destination * progress) * size.x, 0.0}, 1.0F);
            return;
        }
        slides.erase(slide);
    }
    for (const auto& ref : g_pCompositor->getWorkspaces()) {
        const auto ws = ref.lock();
        if (!ws || ws->m_isSpecialWorkspace || ws->m_monitor != mon) continue;
        if (ws != mon->m_activeWorkspace && !ws->m_forceRendering && !ws->m_renderOffset->isBeingAnimated()) continue;
        // Upstream's key mechanism: use the same live offset as workspace windows.
        const Vector2D origin = ws->m_renderOffset->value() * mon->m_scale;
        draw(ws->m_id, origin, ws->m_alpha->value());
    }
}

void cleanup() {
    renderListener.reset();
    tickListener.reset();
    workspaceListener.reset();
    releaseLater.reset();
    held.clear();
    if (notifySource) wl_event_source_remove(notifySource);
    notifySource = nullptr;
    if (notifyFd >= 0) close(notifyFd);
    notifyFd = -1;
    walls.clear();
    lastDraws.clear();
    lastFrames.clear();
    slides.clear();
}
} // namespace

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (std::string_view(__hyprland_api_get_hash()) != __hyprland_api_get_client_hash())
        throw std::runtime_error("hyprmosaic: compositor ABI differs from the pinned build");
    const auto* runtime = getenv("XDG_RUNTIME_DIR");
    const auto* instance = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (!runtime || !instance) throw std::runtime_error("hyprmosaic: missing session environment");
    session = std::filesystem::path(runtime) / "hypr" / instance;
    dirty = true;
    notifyFd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (notifyFd < 0 || inotify_add_watch(notifyFd, session.c_str(), IN_MOVED_TO | IN_CLOSE_WRITE | IN_DELETE) < 0) {
        cleanup();
        throw std::runtime_error("hyprmosaic: unable to watch wallpaper assignments");
    }
    notifySource = wl_event_loop_add_fd(g_pCompositor->m_wlEventLoop, notifyFd, WL_EVENT_READABLE, onNotify, nullptr);
    if (!notifySource) {
        cleanup();
        throw std::runtime_error("hyprmosaic: unable to register assignment watcher");
    }
    workspaceListener = Event::bus()->m_events.workspace.active.listen([](PHLWORKSPACE ws) { holdMovingWorkspaces(); beginSlide(ws); });
    tickListener = Event::bus()->m_events.tick.listen(tick);
    renderListener = Event::bus()->m_events.render.stage.listen([](eRenderStage stage) {
        if (stage == RENDER_POST_WALLPAPER) render();
    });
    statusCommand = HyprlandAPI::registerHyprCtlCommand(handle, SHyprCtlCommand{"hyprmosaic:status", true,
        [](eHyprCtlOutputFormat, std::string) {
            size_t count = 0;
            for (const auto& [_, images] : walls) count += images.size();
            return nlohmann::json({{"resident_images", count}, {"draws", lastDraws}}).dump();
        }});
    damageMonitors();
    return {"hyprmosaic", "Workspace-linked wallpapers (0.55.4 wallpaper-only backport)", "La5u; local adaptation", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() { cleanup(); statusCommand.reset(); }

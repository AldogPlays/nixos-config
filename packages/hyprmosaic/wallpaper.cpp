// Wallpaper-only adaptation of La5u/hyprmosaic, revision 7597c5ef1fc7ce7265a0117089cf88da7cd7e08f.
// Copyright (c) 2026 La5u. SPDX-License-Identifier: MIT
// Upstream LICENSE (including its Hyprland attribution) is installed with the plugin.
// No grid gestures, binary hooks, or compositor patch. Targets Hyprland 0.55.4.

#include <algorithm>
#include <charconv>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <fcntl.h>
#include <fstream>
#include <map>
#include <memory>
#include <set>
#include <stdexcept>
#include <sys/file.h>
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
    std::shared_ptr<const std::string> path;
    SP<Render::ITexture> texture;
};
struct Draw {
    WORKSPACEID id;
    Vector2D origin;
    // Keep diagnostic paths alive across manifest changes, without copying
    // strings every frame or retaining superseded GPU textures for status.
    std::shared_ptr<const std::string> path;
};
using Wallpapers = std::map<std::string, std::map<WORKSPACEID, Wallpaper>>;
Wallpapers walls;
std::filesystem::path session;
bool dirty = true;
int notifyFd = -1;
wl_event_source* notifySource = nullptr;
CHyprSignalListener renderListener, tickListener, workspaceListener;
SP<SHyprCtlCommand> statusCommand;
std::map<std::string, std::vector<Draw>> lastDraws;
nlohmann::json loadedPrepared;
bool prunePending = false;
size_t textureUploads = 0, manifestLoads = 0;
std::vector<PHLWORKSPACE> held;
UP<SEventLoopDoLaterLock> releaseLater;
UP<SEventLoopDoLaterLock> pruneLater;
cairo_user_data_key_t bmpPixelsKey;

// Never wait for preparation on the compositor thread. Holding the helper's
// lock also prevents it from pruning a BMP while we are decoding that file.
struct CacheLock {
    int fd = -1;
    explicit CacheLock(const std::filesystem::path& path) {
        fd = open(path.c_str(), O_RDONLY | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0600);
        if (fd >= 0 && flock(fd, LOCK_EX | LOCK_NB) != 0) {
            close(fd);
            fd = -1;
        }
    }
    ~CacheLock() { if (fd >= 0) close(fd); }
    CacheLock(const CacheLock&) = delete;
    CacheLock& operator=(const CacheLock&) = delete;
    explicit operator bool() const { return fd >= 0; }
};

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

void scheduleCachePrune();

void reloadImages() {
    CacheLock lock(session / "workspace-wallpapers.lock");
    if (!lock) return;
    dirty = false;
    std::ifstream input(session / "workspace-wallpapers.json");
    const auto state = nlohmann::json::parse(input, nullptr, false);
    if (state.is_discarded() || !state.is_object() || !state.contains("prepared") || !state["prepared"].is_object())
        return; // Incomplete/malformed state must not remove a working backdrop.
    prunePending = false;
    Wallpapers next;
    bool complete = true;
    // Reuse across workspace/output changes and within this manifest. Entries
    // not referenced by the new walls expire when this local map is destroyed.
    std::map<std::string, Wallpaper> reusable;
    for (const auto& [_, images] : walls)
        for (const auto& [id, wall] : images) reusable.try_emplace(*wall.path, wall);
    for (const auto& [output, entries] : state["prepared"].items()) {
        if (!entries.is_object()) { complete = false; continue; }
        for (const auto& [key, value] : entries.items()) {
            WORKSPACEID id = 0;
            const auto [end, ec] = std::from_chars(key.data(), key.data() + key.size(), id);
            if (ec != std::errc{} || end != key.data() + key.size() || id <= 0 || !value.is_string()) {
                complete = false;
                continue;
            }
            const std::filesystem::path path = value.get<std::string>();
            // Only read the helper's display-sized BMPs, never arbitrary originals.
            if (path.parent_path() != session / "workspace-wallpaper-images" || path.extension() != ".bmp") {
                complete = false;
                continue;
            }
            const auto oldOutput = walls.find(output);
            const Wallpaper* old = nullptr;
            if (oldOutput != walls.end()) {
                const auto it = oldOutput->second.find(id);
                if (it != oldOutput->second.end()) old = &it->second;
            }
            if (const auto cached = reusable.find(path.string()); cached != reusable.end()) {
                next[output][id] = cached->second;
                continue;
            }
            Hyprgraphics::CImage image(path.string());
            if (!image.success()) {
                complete = false;
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
                complete = false;
                if (old) next[output][id] = *old;
                continue;
            }
            auto texture = g_pHyprRenderer->createTexture(surface->cairo());
            if (texture) {
                // That loader also inserts zero alpha. These RGB wallpapers
                // must ignore it, or repeated blending accumulates to white.
                texture->m_type = Render::TEXTURE_RGBX;
                texture->m_opaque = true;
                Wallpaper wall{std::make_shared<const std::string>(path.string()), texture};
                reusable.emplace(path.string(), wall);
                next[output][id] = std::move(wall);
                ++textureUploads;
            }
            else {
                complete = false;
                if (old) next[output][id] = *old;
            }
        }
    }
    // As with the previous renderer, an empty collection leaves existing images alone.
    if (!next.empty()) {
        walls = std::move(next);
        ++manifestLoads;
        if (complete) {
            loadedPrepared = state["prepared"];
            prunePending = true;
            scheduleCachePrune();
        }
    }
}

void pruneLoadedCache() {
    CacheLock lock(session / "workspace-wallpapers.lock");
    if (!lock) return;
    prunePending = false;
    std::ifstream input(session / "workspace-wallpapers.json");
    const auto latest = nlohmann::json::parse(input, nullptr, false);
    // A newer publication may already be waiting for its first render. Never
    // remove files for that generation, even if the previous one loaded fully.
    if (!latest.is_object() || !latest.contains("prepared") || latest["prepared"] != loadedPrepared) return;
    std::set<std::filesystem::path> keep;
    for (const auto& [_, images] : walls)
        for (const auto& [id, wall] : images) keep.emplace(*wall.path);
    std::error_code ec;
    const auto cache = session / "workspace-wallpaper-images";
    for (std::filesystem::directory_iterator it(cache, ec), end; !ec && it != end; it.increment(ec)) {
        const auto name = it->path().filename().string();
        if (name.size() != 68 || !name.ends_with(".bmp") ||
            !std::all_of(name.begin(), name.end() - 4, [](char c) { return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'); })) continue;
        std::error_code fileError;
        // Only generated regular BMPs; preserve symlinks and unrelated files.
        if (std::filesystem::is_regular_file(it->symlink_status(fileError)) && !keep.contains(it->path()))
            std::filesystem::remove(it->path(), fileError);
    }
}

void scheduleCachePrune() {
    if (pruneLater) return;
    pruneLater = g_pEventLoopManager->doLaterLock([] {
        pruneLater.reset();
        if (prunePending) pruneLoadedCache();
    });
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
    // A helper closes its writable lock file after publication/pruning. That
    // event retries deferred loads and cleanup without timers or idle polling.
    if (prunePending) scheduleCachePrune();
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
    auto& draws = lastDraws[mon->m_name];
    draws.clear();
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
        draws.push_back({id, origin, image->second.path});
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
    pruneLater.reset();
    held.clear();
    if (notifySource) wl_event_source_remove(notifySource);
    notifySource = nullptr;
    if (notifyFd >= 0) close(notifyFd);
    notifyFd = -1;
    walls.clear();
    lastDraws.clear();
    loadedPrepared = nullptr;
    prunePending = false;
    textureUploads = manifestLoads = 0;
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
            std::set<const Render::ITexture*> textures;
            for (const auto& [_, images] : walls) count += images.size();
            for (const auto& [_, images] : walls)
                for (const auto& [id, wall] : images) textures.insert(wall.texture.get());
            auto draws = nlohmann::json::object();
            for (const auto& [output, records] : lastDraws) {
                auto& entries = draws[output] = nlohmann::json::array();
                for (const auto& draw : records)
                    entries.push_back({{"workspace", draw.id}, {"x", draw.origin.x}, {"y", draw.origin.y}, {"image", *draw.path}});
            }
            return nlohmann::json({{"resident_images", count}, {"resident_textures", textures.size()},
                {"texture_uploads", textureUploads}, {"manifest_loads", manifestLoads}, {"draws", draws}}).dump();
        }});
    damageMonitors();
    return {"hyprmosaic", "Workspace-linked wallpapers (0.55.4 wallpaper-only backport)", "La5u; local adaptation", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() { cleanup(); statusCommand.reset(); }

-- Managed by Home Manager from this repository.
-- Home Manager substitutes shared theme settings.

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1.0,
})

local terminal = "uwsm app -- alacritty"
local fileManager = "uwsm app -- dolphin"
local menu = "rofi -show drun"
local mainMod = "SUPER"

hl.env("XCURSOR_THEME", "@CURSOR_THEME@")
hl.env("HYPRCURSOR_THEME", "@CURSOR_THEME@")
hl.env("XCURSOR_SIZE", "@CURSOR_SIZE@")
hl.env("HYPRCURSOR_SIZE", "@CURSOR_SIZE@")

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 4,
        border_size = 1,
        col = {
            active_border = "rgb(@THEME_ACTIVE_BORDER@)",
            inactive_border = "rgb(@THEME_INACTIVE_BORDER@)",
        },
        resize_on_border = true,
        snap = { enabled = false },
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 4,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = false },
        blur = {
            enabled = true,
            size = @BLUR_SIZE@,
            passes = @BLUR_PASSES@,
            noise = @BLUR_NOISE@,
            contrast = @BLUR_CONTRAST@,
            brightness = @BLUR_BRIGHTNESS@,
            vibrancy = @BLUR_VIBRANCY@,
        },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    cursor = { inactive_timeout = 5 },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
            disable_while_typing = false,
        },
    },
    misc = {
        -- Keep the opaque lock screen isolated from the live desktop.
        session_lock_xray = false,
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = "rgb(@THEME_BACKGROUND@)",
    },
})

-- Blur translucent shell backplates, not the fully transparent surrounding area.
hl.layer_rule({
    name = "frosted-shell",
    match = { namespace = "^(waybar|rofi)$" },
    blur = true,
    ignore_alpha = 0.2,
})

-- Version-matched wallpaper-only plugin; native workspace controls stay unchanged.
hl.plugin.load("@HYPRMOSAIC_PLUGIN@")

-- Focus-dependent glass applies to normal application windows, not just terminals.
hl.window_rule({
    name = "window-focus-opacity",
    match = { class = ".*" },
    opacity = "@FOCUSED_OPACITY@ override @UNFOCUSED_OPACITY@ override 1.0 override",
})

-- Later exceptions override the generic rule without exempting all floaters.
hl.window_rule({
    name = "opaque-modal-dialogs",
    match = { modal = true },
    opacity = "1.0 override 1.0 override 1.0 override",
})

-- Both keyboard and Waybar launches use these dedicated Alacritty app IDs.
hl.window_rule({
    name = "float-system-controls",
    match = { class = "^(wlctl|bluetui|wiremix)$" },
    float = true,
})

-- Firefox-family PiP has a dedicated title; ordinary browser tabs are unaffected.
local pipSize = { x = 480, y = 270 }
hl.window_rule({
    name = "opaque-browser-pip",
    match = {
        class = "(?i)^(librewolf|firefox|org[.]mozilla[.]firefox)$",
        title = "^Picture-in-Picture$",
    },
    float = true,
    size = string.format("%d %d", pipSize.x, pipSize.y),
    opacity = "1.0 override 1.0 override 1.0 override",
})

-- Floating rules run at map time. Cover a delayed PiP title and existing PiP
-- windows on reload with native events, without polling or an extra service.
local sizedPipWindows = {}
local function floatBrowserPip(window)
    if not window or not window.mapped or window.title ~= "Picture-in-Picture" then return end
    local class = string.lower(window.class or "")
    if class == "librewolf" or class == "firefox" or class == "org.mozilla.firefox" then
        if not window.floating then
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = window }))
        end
        -- Set a compact initial size once, not on every metadata change, so
        -- resizing manually remains possible afterward.
        if not sizedPipWindows[window.address] then
            hl.dispatch(hl.dsp.window.resize({ x = pipSize.x, y = pipSize.y, window = window }))
            sizedPipWindows[window.address] = true
        end
    end
end
local function scheduleBrowserPip(window)
    if not window or window.title ~= "Picture-in-Picture" then return end
    -- A metadata event can precede the remaining class/layout updates.
    hl.timer(function() floatBrowserPip(window) end, { timeout = 1, type = "oneshot" })
end
hl.on("window.open", scheduleBrowserPip)
hl.on("window.title", scheduleBrowserPip)
hl.on("window.class", scheduleBrowserPip)
hl.on("window.close", function(window)
    if window then sizedPipWindows[window.address] = nil end
end)
hl.on("config.reloaded", function()
    for _, window in ipairs(hl.get_windows()) do scheduleBrowserPip(window) end
end)

-- Waybar is useful with tiles or the launcher, not over an empty desktop.
-- Invisible Waybar stays mapped but uses our configured bottom layer; the
-- visible bar uses the top layer. Query that real state instead of caching it.
local waybarUpdateQueued = false
local waybarSignalPending = false
local waybarDirty = false
local waybarTrayPinned = false
local scheduleWaybarVisibility
local function updateWaybarVisibility()
    local wanted, present, visible = waybarTrayPinned, false, false
    for _, layer in ipairs(hl.get_layers()) do
        if layer.mapped then
            if layer.namespace == "rofi" then wanted = true end
            if layer.namespace == "waybar" then
                present = true
                visible = layer.layer == 2 -- zwlr_layer_shell_v1 top
            end
        end
    end
    local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
    if workspace then
        for _, window in ipairs(workspace:get_windows()) do
            if window.mapped and not window.hidden and not window.floating then
                wanted = true
                break
            end
        end
    end
    if not present or wanted == visible then return end
    waybarSignalPending = true
    hl.dispatch(hl.dsp.exec_cmd("@WAYBAR_SYSTEMCTL@ --user kill --kill-whom=main --signal=SIGUSR1 waybar.service"))
    hl.timer(function()
        waybarSignalPending = false
        if waybarDirty then
            waybarDirty = false
            scheduleWaybarVisibility()
        end
    end, { timeout = 100, type = "oneshot" })
end
scheduleWaybarVisibility = function()
    if waybarSignalPending then waybarDirty = true; return end
    if waybarUpdateQueued then return end
    waybarUpdateQueued = true
    hl.timer(function()
        waybarUpdateQueued = false
        updateWaybarVisibility()
    end, { timeout = 20, type = "oneshot" })
end
for _, event in ipairs({
    "window.open", "window.close", "window.destroy", "window.active",
    "window.move_to_workspace", "window.update_rules", "workspace.active",
    "monitor.focused", "monitor.added", "monitor.removed", "config.reloaded",
}) do
    hl.on(event, scheduleWaybarVisibility)
end
for _, event in ipairs({ "layer.opened", "layer.closed" }) do
    hl.on(event, function(layer)
        if layer and (layer.namespace == "rofi" or layer.namespace == "waybar") then
            scheduleWaybarVisibility()
        end
    end)
end
scheduleWaybarVisibility()

-- One renderer, no listener daemon. File preparation runs outside the compositor.
local wallpaperUpdateQueued = false
local wallpaperKnown = {}
local function scheduleWorkspaceWallpaper()
    if wallpaperUpdateQueued then return end
    wallpaperUpdateQueued = true
    hl.timer(function()
        wallpaperUpdateQueued = false
        hl.dispatch(hl.dsp.exec_cmd("@WORKSPACE_WALLPAPERS@"))
    end, { timeout = 1, type = "oneshot" })
end
-- Numbered workspaces are prepared up front. Only a newly seen extra ID needs
-- reconciliation; normal switches and swipes do not launch a process.
for number = 1, 10 do wallpaperKnown[number] = true end
hl.on("workspace.active", function(workspace)
    if workspace and workspace.id > 0 and not wallpaperKnown[workspace.id] then
        wallpaperKnown[workspace.id] = true
        scheduleWorkspaceWallpaper()
    end
end)
for _, event in ipairs({
    "workspace.move_to_monitor", "monitor.added", "monitor.removed",
    "monitor.layout_changed", "config.reloaded",
}) do
    hl.on(event, scheduleWorkspaceWallpaper)
end
-- Align to quarter-hour boundaries so reloading config preserves the cycle.
local function scheduleWallpaperRotation()
    local seconds = @WALLPAPER_INTERVAL@ - (os.time() % @WALLPAPER_INTERVAL@)
    hl.timer(function()
        scheduleWorkspaceWallpaper()
        scheduleWallpaperRotation()
    end, { timeout = seconds * 1000 + 100, type = "oneshot" })
end
scheduleWallpaperRotation()
scheduleWorkspaceWallpaper()

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
-- Wallpaper and windows now share this exact movement; no fade timing compensation.
hl.curve("workspaceSmooth", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })
hl.animation({ leaf = "global", enabled = true, speed = 8, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "easeOutQuint" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "quick" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "workspaceSmooth" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("uwsm app -- librewolf --new-window about:blank"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.exec_cmd("uwsm app -- joplin-desktop"),
    { description = "Open Joplin" })
hl.bind(mainMod .. " + K", hl.dsp.layout("togglesplit"),
    { description = "Toggle focused tile split: top/bottom or side-by-side" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mainMod .. " + SHIFT + T", function()
    waybarTrayPinned = not waybarTrayPinned
    scheduleWaybarVisibility()
    local signal = waybarTrayPinned and "SIGRTMIN+8" or "SIGRTMIN+9"
    hl.dispatch(hl.dsp.exec_cmd("@WAYBAR_SYSTEMCTL@ --user kill --kill-whom=main --signal=" .. signal .. " waybar.service"))
end, { description = "Toggle the app tray" })
-- Escape quits only these control windows, including an active TUI prompt.
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd([[uwsm app -- alacritty --class wlctl -o 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' -e wlctl]]))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd([[uwsm app -- alacritty --class bluetui -o 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' -e bluetui]]))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd([[uwsm app -- alacritty --class wiremix -o 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' -e wiremix]]))
hl.bind("PRINT", hl.dsp.exec_cmd("screenshot"),
    { description = "Capture a window, or the monitor by selecting a gap" })

hl.bind("ALT + Return", hl.dsp.window.fullscreen({ action = "toggle" }),
    { description = "Alt+Enter: toggle fullscreen" })

for _, direction in ipairs({
    { key = "left", x = -20, y = 0 },
    { key = "right", x = 20, y = 0 },
    { key = "up", x = 0, y = -20 },
    { key = "down", x = 0, y = 20 },
}) do
    hl.bind(mainMod .. " + CTRL + " .. direction.key,
        hl.dsp.focus({ direction = direction.key }),
        { repeating = true, description = "Focus window " .. direction.key })
    hl.bind(mainMod .. " + " .. direction.key, function()
        local window = hl.get_active_window()
        if not window then return end
        if window.floating then
            hl.dispatch(hl.dsp.window.move({
                x = direction.x, y = direction.y, relative = true, window = window,
            }))
        else
            hl.dispatch(hl.dsp.window.move({ direction = direction.key, window = window }))
        end
    end, { repeating = true })
    hl.bind(mainMod .. " + SHIFT + " .. direction.key,
        hl.dsp.window.resize({ x = direction.x, y = direction.y, relative = true }),
        { repeating = true })
end

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Lenovo's bare screenshot hotkey may emit Meta+Shift+S instead of Print.
-- Both hardware variants use the same screenshot picker.
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("screenshot"),
    { description = "Capture a window, or the monitor by selecting a gap" })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "float-modal-dialogs",
    match = { modal = true },
    float = true,
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

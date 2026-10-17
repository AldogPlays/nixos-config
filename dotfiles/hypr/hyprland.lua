-- Managed by Home Manager from this repository.
-- Home Manager substitutes the plugin path from the same nixpkgs as Hyprland.
hl.plugin.load("@HYPRSPACE_PLUGIN@")

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1.0,
})

local terminal = "alacritty"
local fileManager = "dolphin"
local menu = "rofi -show drun"
local mainMod = "SUPER"

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 4,
        border_size = 1,
        col = {
            active_border = { colors = { "rgba(89b4faff)", "rgba(a6e3a1ff)" }, angle = 45 },
            inactive_border = "rgba(585b70aa)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 4,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 0.96,
        shadow = {
            enabled = false,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.17,
        },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
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
        force_default_wallpaper = -1,
        disable_hyprland_logo = false,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.animation({ leaf = "global", enabled = true, speed = 8, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "easeOutQuint" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "quick" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeOutQuint" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("librewolf --new-window about:blank"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("alacritty --class wlctl -e wlctl"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("alacritty --class bluetui -e bluetui"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("alacritty --class wiremix -e wiremix"))
hl.bind("PRINT", hl.dsp.exec_cmd("snap"))
hl.bind(mainMod .. " + TAB", function()
    hl.plugin.overview.toggle()
end, { description = "Toggle Hyprspace overview" })

hl.bind("ALT + Return", hl.dsp.window.fullscreen({ action = "toggle" }),
    { description = "Alt+Enter: toggle fullscreen" })

for _, direction in ipairs({
    { key = "left", x = -20, y = 0 },
    { key = "right", x = 20, y = 0 },
    { key = "up", x = 0, y = -20 },
    { key = "down", x = 0, y = 20 },
}) do
    hl.bind(mainMod .. " + " .. direction.key, hl.dsp.window.move({ direction = direction.key }))
    hl.bind(mainMod .. " + SHIFT + " .. direction.key,
        hl.dsp.window.resize({ x = direction.x, y = direction.y, relative = true }),
        { repeating = true })
end

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
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

# Waybar patches

I override pinned Waybar with a small extension to its native drawer group. The
tray expands to the left inside the bar using GTK's existing revealer and native
StatusNotifier icons and application menus. No extra window, tray host, or
service is started.

`drawer.signal = 8` adds the symbolic arrow and caches the signal number during
construction (upstream passes a constructor-local JSON copy). SIGRTMIN+8 opens
and pins the drawer; SIGRTMIN+9 closes it. Hyprland's Meta+Shift+T binding sends
these explicit commands and reveals the focused screen's bar while pinned, even
on an empty workspace. Hover opens temporarily and pointer exit closes it
unless pinned. The stylesheet rotates the arrow to indicate expansion.

After a Waybar input upgrade, I rebase the patch against
`group.hpp`/`group.cpp`, build, and manually check hover, Meta+Shift+T, native
app menus, empty tray state, and visibility on an empty workspace. Restart
`waybar.service` after code changes.

`per-output-visibility.patch` adds an opt-in `visibility-signal` bar setting.
With `visibility-signal = 10`, SIGRTMIN+10 reads the atomic
`$XDG_RUNTIME_DIR/waybar-output-visibility.json` object, whose output-name keys
contain boolean visibility states. Each bar applies its own explicit state via
the native `setVisible` method. Missing or invalid states leave visibility alone;
the regular SIGUSR2 reload behavior is preserved. The
`dotfiles/hypr/waybar-policy.lua` module owns tray pin state, event coalescing and
pending signals. Its `toggleTray` action is used directly by the compositor
binding. The policy writes this manifest from visible windows per monitor, including floating and pinned
windows, then signals the existing service. No listener daemon or polling is added.

`workspace-groups.patch` adds opt-in `hide-empty-groups` and
`workspace-group-size` settings to the native Hyprland workspace module. A group
is occupied when any of its native per-monitor workspaces contains a window.
Unused group buttons are hidden, while visible and urgent desktops remain shown.
Persistent native workspaces stay available for swipes and keyboard navigation.
The existing name-to-icon mapping supplies logical desktop numbers; the shared
stylesheet highlights `.visible` on every bar rather than globally focused
`.active`. Check group occupancy, closure of the final window, switching from
each screen and hotplug after Waybar upgrades.

`lua-workspace-dispatch.patch` adds `lua-dispatch = true` to opt workspace
buttons into Hyprland 0.55's Lua IPC syntax. Numbered, named and special workspace
buttons use native `hl.dsp` dispatchers; the default remains the upstream command
syntax for other configurations. Workspace scrolling in the Home Manager module
uses the same Lua IPC. Check this patch when upgrading Waybar or Hyprland.

`network-address-family.patch` backports the family-specific address-removal
handling from [upstream Waybar](https://github.com/Alexays/Waybar/blob/master/src/modules/network.cpp).
Waybar 0.15.0 clears both cached address families when either loses an address.
With IPv6 temporary-address expiry, this can erase a still-valid IPv4 address
and leave the module showing its linked-without-IP icon instead of Wi-Fi details.
The patch clears only the removed address's family. It leaves network settings,
module styling and the existing session service unchanged. On upgrades, check
whether upstream already includes this correction before retaining the patch.

`nix build .#checks.x86_64-linux.waybar-reader --no-link` compiles the actual
patched `Bar::handleSignal` method with the pinned JSON reader and a minimal
bar surface boundary. It checks independent output states, missing entries,
invalid values, missing runtime files and ordinary signal forwarding without
starting a graphical bar. The Lua policy scenarios run in the
`workspace-wallpapers` check; neither check establishes live drawer rendering.

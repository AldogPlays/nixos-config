# System context and decisions

This is a reference for the intended system and choices that affect future work.
The Nix configuration is authoritative for exact values. This document does not
establish what is currently activated or running; inspect the host when needed.
Git history records changes. The bootstrap observations in `audit.md` are historical.

## Machine and configuration

The host is `nixos`, an `x86_64-linux` Lenovo IdeaPad 5 2-in-1 14AKP10, with primary
user `jeffreyc`. Hardware includes a Ryzen AI 7 350, Radeon 860M, AMD XDNA NPU,
MediaTek MT7925 Wi-Fi, roughly 13 GiB usable RAM, and a 476.9 GiB NVMe SSD.
Touchscreen, Wacom pen/touch, and tablet mode matter when evaluating hardware or
desktop changes.

AMD VA-API decoding comes from the declared Mesa graphics stack. On 2026-10-19,
an isolated LibreWolf 158 profile using the installed defaults confirmed native
Wayland/WebRender, VA-API initialization and `IsHardwareAccelerated=true` during
1080p H.264 playback (180 frames, zero dropped over about six seconds). The browser
also advertised hardware H.264, VP9, AV1 and HEVC decoding; VP8 was software-only.
No extra browser preferences, forced driver overrides or sandbox changes were
needed. This test does not establish that every site/stream uses hardware decoding.

The stable OS input is `nixos-26.05`. Home Manager follows it through
`release-26.05`; `flake.lock` pins revisions. A separate unstable input supplies
Codex so that tool can advance independently of the OS base. Home Manager is
integrated into the NixOS rebuild, rather than maintained as a separate switch.
Both compatibility baselines are `26.05`.

`nix run .#bootstrap` previews a portable fresh-install adoption; `--apply` builds,
backs up and activates it. It targets other x86-64 PCs too, preserving their own
user, disk/encryption, initrd, bootloader and graphics selections. Shared hardware
services now live in `modules/nixos/hardware.nix`; CPU/disk details stay in host
modules. The original Lenovo target retains its settings. Generated hosts pin a
project source snapshot and rebuild through `/etc/nixos`; rerun bootstrap from a
new project revision to update that snapshot. See README for authentication,
supported layouts, recovery and the remaining fresh-install deployment test.

The official ChatGPT desktop app provides graphical Codex alongside the Codex CLI.
Both are declared from the pinned unstable input; the Linux desktop launcher is
`chatgpt`. This uses nixpkgs' adaptation of the official application binary.

Cisco Packet Tracer is supplied by pinned nixpkgs, launched as `packettracer9` or
through its desktop entry. The package selects XWayland locally. Cisco's matching
installer is a separately downloaded input: bootstrap verifies and imports it
from `~/Downloads` when absent from the store. See README for the exact version
and manual import command; binaries, license state and Cisco credentials stay
outside the repository.

Joplin Desktop is declared in `home/jeffreyc/packages.nix` from the pinned unstable
input to meet the requested version above 3.7.0; stable nixpkgs supplies 3.5.13.
It launches from the app menu or `joplin-desktop`; no autostart service or sync
account is configured. Notes and application preferences remain user-managed.

Steam is enabled through the NixOS module in `modules/nixos/hyprland.nix`.
That module supplies its runtime and `steam-run`, enables 32-bit graphics/audio,
and adds controller udev rules plus the `uinput` kernel module. Steam launches
on demand; no autostart or gaming daemon is added. Valve's Proton is managed by
Steam; separate Wine, custom Proton builds, overlays and tuning utilities are
not part of this minimal setup. Steam-specific firewall openings stay disabled.
Portable bootstrap treats captured 32-bit graphics support as a default so
Steam's required support takes precedence even on a previously 64-bit-only host.

Lutris is declared in `home/jeffreyc/packages.nix` using the pinned nixpkgs FHS
runtime package. It launches on demand from Rofi or `lutris`, without a new
background service. Game installations, downloaded runners and account sign-ins
remain user-managed; the existing Steam module supplies host 32-bit graphics.

The kernel selection is `pkgs.linuxPackages_latest` from the stable input. Recent
hardware support is a consideration when reviewing that choice, but a specific
requirement for this kernel has not been established.

The systemd-boot menu is hidden for normal startup; hold Space during firmware
startup to open it and select an earlier generation. A persistent EFI menu-timeout
override takes precedence over the declared timeout, so clear an old override
with `sudo bootctl set-timeout ''` after activating the configuration. This does
not change disk-unlock or login authentication.

Root is LUKS-encrypted Btrfs, mounted at the top level. `/home` and `/nix` are
separate subvolumes sharing its capacity. `/boot` is a separate EFI partition;
swap is a separate encrypted 8.8 GiB partition. There is no declared resume device,
snapshot policy, or Btrfs compression setting. Recovery tooling requires a design
appropriate to this layout. Weekly Nix garbage collection retains according to
`--delete-older-than 30d`; it is not a personal-data backup.

Home Manager's conflicting-file backup suffix is `.hm-backup`. The current editor
is Nano, shell is Bash, locale is `en_US.UTF-8`, and timezone is
`America/Los_Angeles`.

Starship is the Bash prompt, integrated through Home Manager in `programs.nix`.
It shows a single line with directory, Git branch/status and success/error arrow,
with colors from shared theme roles. No custom command modules, language-version
segments or background service are configured. Existing shells need reinitializing;
new interactive Bash shells load it automatically.

Interactive Bash also loads pinned ble.sh before completion/Starship and attaches
it afterward, only on a real terminal. It adds local history/completion ghost
suggestions and syntax highlighting without changing shells. Tab performs normal
command/path completion; Right Arrow accepts a suggestion at the end of the line.
The generated rc file is store-managed, not a second user-maintained theme.
Existing command names remain: interactive `ls`/`ll` use eza; `command ls`
retains GNU behavior. Git uses delta as its diff/show/log/blame pager and
interactive diff filter. Delta's syntax theme is deliberately disabled rather
than importing a second bat palette; shared roles color changes and emphasis.
No cat/grep/cd replacement or additional shell service is declared. Scripts and
unpiped native-tool semantics should not be inferred from interactive aliases;
eza is not fully GNU-ls flag-compatible.
Eza adds file-type icons only on terminal output, using the existing Nerd Font
symbols. It does not supply image thumbnails or interactive content previews.

## Desktop components

Hyprland handles cursor hiding with its native inactivity timeout, without an
idle daemon. Meta+J uses Dwindle's `togglesplit` for the focused tile's parent
split, with split preservation enabled; it is not a whole-workspace rotation.

These are declared choices, subject to Jeffrey's review rather than a commitment
to keep every bootstrap component.

SwayNC keeps only its title, do-not-disturb switch and notification list. Its
content-sized panel, compact spacing, small icons and flat controls are declared
in `home/jeffreyc/desktop.nix`, consuming shared theme colors and font from
`theme/default.nix`. Panel and popup backgrounds are fully opaque, matching
Waybar; their layer surfaces do not request blur. The panel uses the shared main background and
a thin focus-color outline to separate it from applications underneath.
Notification cards and controls have thin outlines, with explicit keyboard-focus indication.
Clear All uses explicit label colors without GTK's additional dimming; when
disabled on an empty list, it keeps readable muted text on the alternate background.
The panel and popups are inset 12px below the usable screen edge and from the
right edge, separating them from tiled-window corners. Layer-shell accounts for
Waybar's reserved space; popup CSS supplies the same inset as the panel margins.
The existing session service provides notifications; no extra theme service is
needed. Reload SwayNC's config and CSS after activation to update a running process.

| Role | Component | Configuration |
| --- | --- | --- |
| Compositor and session | Hyprland, UWSM, XWayland | `modules/nixos/hyprland.nix`; `dotfiles/hypr/hyprland.lua` |
| Login greeter | SDDM with Wayland enabled, minimal themed layout | `modules/nixos/hyprland.nix` |
| Bar and notifications | Waybar, SwayNotificationCenter | `home/jeffreyc/desktop.nix`; Super+N toggles the notification center |
| Launcher | Rofi (native Wayland), Super+A | `home/jeffreyc/programs.nix`; Hyprland bindings |
| Lock screen | hyprlock, Super+L | Home Manager theme, NixOS PAM service; no idle-lock service |
| Terminal and files | Alacritty, Super+T; Dolphin, Super+E | Home Manager programs/packages; Hyprland bindings |
| Browser | LibreWolf | Home Manager `programs.librewolf` in `home/jeffreyc/programs.nix`; session variables |
| Network controls | NetworkManager, wlctl | Click Waybar network or Super+Shift+N to open wlctl in Alacritty |
| Bluetooth controls | BlueZ, Bluetui | Click Waybar Bluetooth or Super+Shift+B to open Bluetui in Alacritty |
| Authentication prompts | polkit, hyprpolkitagent | NixOS desktop module and Home Manager session service |
| Audio | PipeWire, WirePlumber; Jeffrey’s Wiremix fork, wpctl | Click Waybar volume or Super+Shift+A for Wiremix; media keys retain wpctl |
| Portals | Hyprland and GTK backends | Hyprland's NixOS module supplies its portal; GTK is added explicitly |
| Screenshots and clipboard | slurp, grim, wl-clipboard | Print or Meta+Shift+S starts `screenshot`; `home/jeffreyc/packages.nix`, `dotfiles/hypr/screenshot.sh`; no daemon |
| Brightness and media | brightnessctl, playerctl | User packages and Hyprland bindings |
| Fonts | Monaspace Neon, Nerd Font symbols, Noto, Noto Emoji | NixOS desktop module and application settings |
| Wallpaper | hyprmosaic, wallpaper-only backport | Native plugin draws workspace-linked images; Lua events/timer trigger preparation |

Firmware updates, power profiles, and battery state are supported by fwupd,
power-profiles-daemon, and UPower. `power-source-profile.service`, declared in
`modules/nixos/hardware.nix`, runs the repository's Python policy at system boot.
It listens for UPower and power-profile D-Bus changes without polling. Automatic
selection is Performance on AC, Balanced on battery, and Power Saver at or below
20%. A manual profile change stays in effect until the power source changes;
service restart also resets it. Hosts without Performance fall back to Balanced.
The daemon's native battery-aware hardware tuning remains enabled: it adjusts
tuning within the selected profile, rather than replacing this selection policy.
The service reconnects after backend failure by restarting; it neither replaces
the existing power daemon nor adds TLP or another hardware tuning stack.

Waybar uses its native power-profiles-daemon module for live profile display and
click-to-cycle. Workspaces are the only left-side module; the tray starts the
right group. Flat controls show accented icons and useful numeric values;
their descriptions stay in tooltips, while the battery is a plain readout.
Control icon accents are semantic roles in `theme/default.nix`; value text stays
in the normal foreground. The 12-hour clock has no calendar dropdown or tooltip.
Calendar/Nextcloud integration remains a future choice. Existing Hyprland
visibility events and TUI launchers stay in use.

The app tray expands left within Waybar using its native animated drawer.
Hover opens temporarily; Meta+Shift+T pins it open or closes it. The existing
Lua visibility policy keeps the bar visible while pinned on an empty workspace.
`packages/waybar-tray/` adds a small signal-controlled arrow to the native drawer;
it reuses the existing StatusNotifier tray, menus and process without a separate
window or service. Wi-Fi, volume and battery display icons only, with percentages in
tooltips. The plugged-in/charging battery uses a green battery-with-lightning icon,
distinguishing it from Performance mode's standalone lightning bolt.
Appearance remains driven by shared theme roles.

Wiremix now comes from Jeffrey's published `AldogPlays/wiremix` fork on
`codex/ui-match`, pinned in `flake.lock` and following the system nixpkgs.
`home/jeffreyc/packages.nix` selects the fork instead of stock Wiremix, retaining
the `wiremix` command and desktop entry for both existing floating launchers.
The fork's single-page audio sections and contextual controls replace its UI;
PipeWire/WirePlumber and their startup remain unchanged. No local checkout path,
imperative installation, or extra service is required on a new machine.

The TUI controls are launched on demand; the
network/Bluetooth/audio backend services remain enabled. Their dedicated
Alacritty app IDs float through `dotfiles/hypr/hyprland.lua`. Keyboard and Waybar
launch commands bind unmodified Escape to Alacritty's Quit action for these
windows only, closing even an active TUI prompt. No extra service is involved.
nm-applet, Blueman, and pavucontrol are no longer declared as front ends.

Tailscale is declared in `modules/nixos/core.nix`: the system `tailscaled` daemon
and CLI, with interactive authentication kept outside the repository and store.
No additional GUI, Tailscale SSH, subnet routing, or exit-node setup is declared.

LibreWolf's package policies default downloads to the XDG Downloads folder and
disable the per-download location prompt. Home Manager supplies the browser
through `programs.librewolf`; existing browser profiles remain unmanaged. After
activation, fully quit and reopen LibreWolf to load the policies.

Desktop integration lives in `home/jeffreyc/default.nix`: managed XDG user
directories (including existing Projects), explicit MIME defaults for
LibreWolf/Dolphin and the `codex://` handler, and `xdg-terminal-exec` selecting
Alacritty. The terminal selector is an on-demand command, not a daemon. Standard
folders and Pictures/Screenshots/Wallpapers are created without moving existing
data. MIME configuration that predates Home Manager is backed up rather than
discarded. Gwenview supplies image viewing and quick editing. Dedicated media
player/mail/office/general GUI editor choices remain pending; do not install a
bundle to fill those roles.

Dolphin uses native KDE colors generated from the shared Latte palette in
`home/jeffreyc/desktop.nix`, plus the Qt6 KDE platform plugin, Breeze widget style,
and Breeze icons. Package selections override Home Manager's larger KDE defaults
so this does not add System Settings or a Plasma session. Qt environment settings
also affect other Qt clients. `kdeglobals` and the generated color-scheme file
are managed; `dolphinrc`, Places bookmarks, and per-folder state are preserved.
KDE's terminal settings point to Alacritty for external terminal launches.
The embedded Konsole panel and extra indexer are not installed.
KIO/KIO extras and icon assets already occur in Dolphin's
dependency closure; avoid redundantly adding a KDE bundle for those functions.

Image support uses native Qt `kimageformats` readers, including HEIC/HEIF, AVIF,
JPEG XL and RAW, plus KIO's `kdegraphics-thumbnailers` for PDF/RAW and
`ffmpegthumbs` for video previews. Dolphin's default plugin discovery picks up
the installed thumbnailers; existing preview and per-folder preferences are not
overwritten. Gwenview is the image MIME default (folders stay assigned to Dolphin)
and offers quick crop/resize/rotate/annotation/basic adjustments. It reuses the
existing Qt/KDE theme and starts on demand, with no new service.

Ark is the archive viewer and supplies Dolphin's native extraction/compression
service menus. Archive MIME defaults are derived from its desktop entry rather
than maintained as a separate MIME list. Its native libzip/libarchive plugins
handle common ZIP/tar formats; the maintained upstream 7-Zip package backs the
7z plugin. Pinned Ark 26.04.3 invokes `7z`, while nixpkgs `_7zz` installs `7zz`,
so `home/jeffreyc/packages.nix` adds a compatibility symlink to that same binary.
Do not replace it with an obsolete p7zip package or install an entire KDE bundle.
Ark follows the shared Qt/KDE theme and starts on demand, without a new daemon.

hyprmosaic is the sole wallpaper renderer, built as a wallpaper-only backport
against the pinned Hyprland 0.55.4. `packages/hyprmosaic/` pins upstream source
and retains its license; the local C++ adaptation uses the old API and our
per-output manifest, omitting grid navigation and blurred margins. Wallpaper
textures follow native workspace animation progress. Interrupted horizontal
slides preserve their last rendered positions as a joined strip instead of
copying native position resets that can expose a gap. Window animations remain
untouched; there is no separately timed fade or wallpaper process on ordinary
switches. Native controls stay unchanged. Lua events and its quarter-hour timer launch a short-lived Pillow
helper for remembered assignments and display-sized copies. No extra background
service is added; awww is no longer enabled. The collection and runtime cache
stay outside Git and the Nix store; theme/lock screen stay independent. See
[workspace wallpapers](wallpapers.md) for limits, validation, and recovery.
Preparation shares identical source/size results within each update, and the
renderer shares textures by prepared path. Superseded generated BMPs are removed
only after successful loading, under the helper's nonblocking lock with a fresh
manifest check. Diagnostics serialize on demand rather than during rendering.
These internal optimizations preserve assignments, refresh timing, image quality
and workspace animations.

wlctl is pinned through its upstream flake, following the system nixpkgs input.
Screenshots use an on-demand slurp picker with a slightly bolder shared-theme hover
outline and light dimming outside the selection. Click a visible window for its
rectangle or a gap for that monitor; Escape cancels. Grim captures after selection;
the helper saves a PNG under XDG Pictures/Screenshots and copies it with
wl-clipboard. No editor, preview, OCR,
notification, or screenshot daemon is added. This replaces Snap's capture UI.
Fn+Prt Sc sends Print on this Lenovo. Bare screenshot hotkeys on Lenovo can
send Meta+Shift+S. Print and Meta+Shift+S now launch the same picker; Jeffrey
confirmed the shortcut fix works. The conflicting example scratchpad bindings
are removed. Only the monitor's active workspace (or open special workspace),
plus visible pinned windows, is offered.
Captures crop visible screen pixels rather than reconstructing obscured windows;
slurp's smallest-rectangle selection can be ambiguous for overlapping floating
windows. The same helper and pinned packages are included in portable bootstrap.
Click-and-drag area selection remains a proposal, not an activated behavior:
upstream Slurp supports predefined rectangles for clicks alongside free dragging
when `-r` is omitted. The current helper deliberately retains `-r`; a future
change should check pointer jitter and preserve gap-to-monitor fallback.

## Customization decisions

- The requested look uses 1.0 scaling, compact gaps, thin window frames, restrained
  corners, and no window shadows. Exact geometry lives in the Hyprland and
  Home Manager desktop configurations.
- Ctrl+Meta+Arrow changes focus directionally through Hyprland's native focus
  dispatcher, repeating when held. Meta+Arrow retains layout movement for tiled
  windows, but moves floating windows by relative pixel increments. Meta+Shift+Arrow resizes by
  relative increments. Both repeat when held; mouse snapping is explicitly
  disabled. Waybar uses matching compact top/side margins and rounded corners,
  preserving its exclusive zone so tiled windows do not overlap it.
  Workspace-button backgrounds also have rounded corners, so active/hover fills
  do not paint square corners over the bar's outer rounding. Waybar is visible
  when the focused monitor's active workspace (or active special workspace)
  has a mapped, non-hidden tiled window, or while Rofi is mapped or the app tray is pinned open.
  Floating dialogs/PiP do not count. Native Lua window/workspace/layer events
  reconcile visibility using its standard SIGUSR1 toggle, signaling the main
  process of `waybar.service` through systemd rather than matching wrapped
  executable names. Invisible Waybar stays
  mapped, so the explicit invisible mode uses the bottom layer while the visible
  bar uses top; Lua queries this real state, without a stale visibility cache.
  Small one-shot timers coalesce events and asynchronous signals. No polling loop
  or extra service is added. The existing Home Manager reload signal is preserved.
  Hidden Waybar releases its exclusive zone; visible Waybar reserves
  space as before. Multi-output bars currently share this focused-monitor policy.
- The touchpad should remain usable during typing and use non-natural scrolling.
  Both `disable_while_typing` and `natural_scroll` are false in the Lua source.
- Windows explicitly marked modal float through a single Hyprland rule. Normal
  application windows stay tiled. Modal detection does not use broad title
  heuristics or Bitwarden-specific exceptions; the separate browser PiP rule
  below uses its known dedicated title. Unmarked extension windows may need
  separate inspection if this baseline does not catch them.
- The theme direction is fixed Catppuccin Latte, with locally versioned official
  palette values and shared semantic roles. No switching, refresh coordinator,
  or theme daemon is wanted. See `theme/README.md` for the data contract.
- The material direction is matte frosted glass, not liquid/glossy/refractive
  glass. Normal application windows (including LibreWolf and Dolphin) and Rofi
  use Hyprland background blur. Shared opacity and blur controls
  live under `theme/default.nix.material`. Normal windows use a native
  Hyprland rule for fully opaque focus, 95% opaque unfocused state, and fully opaque
  fullscreen. Their whole surfaces, including text, follow that opacity; native
  Alacritty alpha stays at 1.0 to avoid multiplying two transparency settings.
  Later rules keep explicitly modal windows and recognized LibreWolf/Firefox
  PiP fully opaque, without exempting all floating windows. Recognized PiP also
  floats with a compact initial size defined in the Lua component, without
  forcing placement or pin state. Initial sizing runs once per PiP window (and
  once again after config reload), not on later metadata updates, so manual
  resizing remains available. PiP uses the exact
  English `Picture-in-Picture` title and browser class, researched from Mozilla's
  upstream player/localization sources. Unmarked dialogs and other PiP app/title
  combinations need separate runtime inspection rather than broad title guesses.
  Native Hyprland open/title/class/reload callbacks cover late metadata and
  existing PiP windows because floating rules only apply when a window maps.
  A one-shot next-loop callback allows class/layout updates to finish before
  floating. No polling helper or background service is used.
  Windows and Waybar have thin 1px borders using the shared border roles;
  focused windows use the distinct focus-border role. The login surface remains
  opaque. Hyprlock uses a solid, opaque shared Latte background, without a
  background screenshot, blur or transparency. Session-lock xray is disabled;
  authentication stays unchanged. Keep the pinned Hyprland version rather than
  upgrading or maintaining a compositor patch for lock-screen effects.
  Waybar and SwayNC are fully opaque, using the shared background role independently
  of the glass opacity and window focus.
  Rofi's outer frame remains borderless. The notification-center frame uses a
  thin focus-color outline for separation from underlying apps; input/control
  outlines, separators and status indicators remain useful and are not removed.
  No shader, refraction plugin, highlight gradient, shadow or new service is added.
- Fonts share the family and point size in `theme/default.nix` across terminal,
  launcher, bar, notifications, GTK defaults and KDE UI roles. CSS uses `pt`, not
  `px`, to avoid unit mismatches. Web content and app-specific overrides are not
  forced. Display scaling remains unchanged.
- The cursor intentionally uses packaged Catppuccin Mocha Dark assets for
  contrast on Latte. Home Manager configures Hyprcursor, Xcursor, GTK and KDE;
  this is an asset exception, not a second application palette or theme switcher.
- Generic GTK3 styling uses pinned `adw-gtk3` as widget structure, with generated
  semantic colors from the shared theme. GTK4/libadwaita uses named colors and
  modern CSS variables without replacing its native layout. Light appearance is
  declared through Home Manager's GTK/dconf integration. Legacy GTK2 colors and
  apps isolated from or overriding the host stylesheet are not claimed covered.
- SDDM uses pinned `where-is-my-sddm-theme` as a minimal layout, configured from
  shared colors, typography and cursor settings. Small fail-fast substitutions
  cover its otherwise hardcoded selection/error colors and pulsing error border.
  The theme's QML dependencies are passed through SDDM's `extraPackages`; no
  display-manager replacement or new session service is introduced. Activation
  leaves the running display manager alone; the new configuration takes effect
  when SDDM next starts, normally on the next boot.
- Hyprlock has a generated minimal Latte config and a normal NixOS PAM entry.
  Configure PAM directly rather than enabling the NixOS hyprlock module, which
  implicitly enables hypridle in this pinned release. No idle daemon, auto-lock
  timer, grace period or authentication bypass is requested. Parser checks and
  login-screen test mode do not establish successful real authentication.
- Native theme adapters consume the shared definitions for Hyprland borders,
  Alacritty, Rofi, Waybar, SwayNC, and Dolphin/KDE Qt colors. Keep app-specific syntax in the existing
  modules; do not install independent Catppuccin palettes. Canonical palette
  values stay opaque; shell backplates and normal windows add alpha at the adapter
  boundary. Their displayed tint now intentionally depends on the blurred content
  behind them. See `theme/README.md` for
  researched integration details and the remaining unthemed components.
- GitHub Actions workflows were deliberately removed. Validation stays local
  unless CI is requested. Repository visibility and remote settings need direct
  verification when relevant.

## Repository map

- `flake.nix` and `flake.lock`: inputs, host output, Home Manager integration,
  formatter.
- `hosts/nixos/`: machine identity, account, disk UUIDs, encryption, boot hardware.
- `modules/nixos/`: core OS, AMD/laptop support, and system desktop integration.
- `home/jeffreyc/`: user identity/session variables, packages, programs, desktop.
- `dotfiles/hypr/`: managed Hyprland Lua configuration.
- `theme/`: shared Latte data and adapter contract.
- `tests/`: wallpaper policy and Lua scheduling regression tests.
- `packages/`: local packages for requested tools missing from the pinned nixpkgs.
- `README.md`: setup, rebuild, and maintenance commands.
- `AGENTS.md`: instructions for how agents should work.
- `docs/wallpapers.md`: wallpaper implementation, cache, and troubleshooting.

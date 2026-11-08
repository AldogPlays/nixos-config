# Desktop guide

Keyboard controls, applications and desktop behavior for this configuration.
See [installation](installation.md) for setup and [maintenance](maintenance.md)
for rebuilds and recovery.

## Keyboard and controls

| Action | Shortcut or control |
| --- | --- |
| Terminal (Alacritty) | Meta+T |
| New LibreWolf window | Meta+F |
| Close focused window | Meta+Q |
| Toggle floating | Meta+W |
| Joplin | Meta+J |
| Toggle focused tile split (top/bottom ↔ side-by-side) | Meta+K |
| Toggle fullscreen | Alt+Enter |
| Workspace 1–10 | Meta+1–9, Meta+0 for 10 |
| Move window to workspace | Meta+Shift+1–9 or 0 |
| Focus window in a direction | Ctrl+Meta+Arrow; hold to repeat |
| Move focused window | Meta+Arrow; tiled layout move or 20 px floating move, hold to repeat |
| Resize focused window | Meta+Shift+Arrow; 20 px steps, hold to repeat |
| File browser (Dolphin, new window at Home) | Meta+E |
| App launcher (Rofi) | Meta+A |
| Theme selector (Rofi) | Meta+Ctrl+T |
| Notification center (SwayNC) | Super+N or click the bar's notification icon |
| Do not disturb | Right-click the notification icon |
| Wi-Fi (wlctl) | Super+Shift+N or click the bar's network module |
| Bluetooth (Bluetui) | Super+Shift+B or click the bar's Bluetooth module |
| Audio mixer (Wiremix) | Super+Shift+A or click the bar's volume module |
| System monitor (btop) | Meta+Esc or click the battery icon |
| Power mode | Click Waybar's power-mode icon to cycle available profiles |
| App tray | Hover the arrow or toggle with Meta+Shift+T |
| Screenshot | Prt Sc (with or without Fn on this Lenovo), or Meta+Shift+S; click a window/gap, or drag an area; Escape cancels |

Network, Bluetooth, Audio, and System Monitor controls open as floating Alacritty windows from
either their shortcuts or Waybar. Escape closes the focused control window,
including when a TUI prompt is open. Hyprland's app-ID rule lives in
`dotfiles/hypr/hyprland.lua`; launch commands there and in
`home/jeffreyc/desktop.nix` set the per-window Alacritty Escape binding.

The system monitor shows CPU, memory, network, processes and available battery
information. Its native btop theme follows the shared desktop colors through
`home/jeffreyc/programs.nix`. It starts through UWSM on demand, without a monitoring
daemon. Escape closes the window, including while a btop menu is open.

Keyboard app shortcuts, Waybar's system controls and apps started by Rofi use
`uwsm app --` to launch in separate application units. Hyprland's service has an
`OOMPolicy=continue` drop-in so an inherited app's memory kill does not terminate
the entire session. The drop-in is in `home/jeffreyc/desktop.nix`; reload it with
`systemctl --user daemon-reload`, without restarting the compositor. This
contains application failures but does not prevent memory exhaustion itself.

Meta and Super both refer to the Windows/logo key. Resize Left/Up shrinks the
window's width/height; Right/Down grows it. Tiled resizing respects the layout.
Floating windows move and resize in pixel increments instead of snapping to
screen edges. Mouse snapping is disabled. Waybar has top/side margins matching
the compact outer window gaps, rounded corners and a thin 1px border; it still
reserves space above tiled windows rather than covering them.
Each screen's bar appears when that screen has a visible window, including a
floating window, PiP, pinned window or window in its open special workspace.
It hides when the screen is empty, independently of mouse focus and the other
screens. Rofi alone does not reveal an empty screen's bar. Meta+Shift+T can
temporarily reveal the focused screen's bar with the tray pinned open.
Native Hyprland Lua events write an atomic per-output visibility manifest in
`$XDG_RUNTIME_DIR` and signal the existing Waybar process. The local Waybar
extension applies explicit show/hide states to each output; no extra daemon or
polling loop is used. Hidden bars release their reserved space.
Other existing controls remain unchanged.
The left side shows workspaces only. On the right, the tray comes first, followed
by network, Bluetooth, volume, power mode, battery and notifications. Flat
controls show icons, with square backgrounds spanning the bar’s
inner height on hover/press; descriptive text stays in their tooltips.
Wi-Fi, Bluetooth, volume and battery show icons only; connection details and
percentages remain in tooltips. All six status icons share the same minimum width,
horizontal padding and inter-module gap. Icon accents come from the selected
theme roles in `theme/`. The clock uses 12-hour time
with AM/PM, without a calendar dropdown or hover popup.
SwayNC uses the same outer spacing as the tiled windows below Waybar.
Its notification center keeps a 600-pixel height even when empty, capped by the
available monitor height; notification text and controls retain compact spacing.
The scrollbar is hidden; wheel and touchpad scrolling still reach older notifications.
Scroll over volume to adjust it in 5% steps. Volume/brightness keys, speaker/mic
mute keys, and volume scrolling show a compact one-second SwayOSD overlay.
`desktop-feedback`, declared in `home/jeffreyc/packages.nix`, retains wpctl and
the existing brightnessctl curve. Home Manager starts `swayosd.service` with the
graphical session; its shared-theme styling lives in `home/jeffreyc/desktop.nix`.
Adwaita’s vector icon assets supply the overlay’s symbolic icons.
Unmuted audio uses low/medium/high icons matching Waybar’s volume bands.
Muted audio still shows its current volume percentage and bar, with a muted icon.
Feedback stays out of notification history. SwayNC remains the notification
center; its empty state is a muted text label without the oversized fallback icon.

### Monitors and shared desktops

The reference desk layout is in `hosts/nixos/monitors.lua`. The Acer KG251Q is
rotated 180° and centered above the P2510S; the laptop stays on to the left,
centered vertically against the P2510S. Both external screens use 120 Hz
(119.98 Hz on the Acer); the laptop retains its preferred mode. All use 1.0 scaling.
EDID descriptions identify the displays when dock connectors
change. Portable bootstrap hosts use automatic placement instead of this desk
layout; the reference host supplies it through its Home Manager module argument.

| Screen | Logical position | Resolution | Rotation |
| --- | --- | --- | --- |
| Laptop | −1920, 120 | 1920×1200 | Normal |
| P2510S, lower | 0, 0 | 2560×1440 at 120 Hz | Normal |
| Acer KG251Q, upper | 320, −1080 | 1920×1080 at 119.98 Hz | 180° |

The local [full-edge cursor plugin](../packages/hyprland-full-edges/README.md)
maps the full edge proportionally to the adjacent screen, including corners
outside the geometrically overlapping section. Moving upward from anywhere on
the P2510S reaches the Acer; moving left reaches the laptop. Outer edges do not
wrap. It loads inside the pinned Hyprland, with no additional service. Pointer
constraints, session locking, and absolute touch/pen input retain native behavior.

`dotfiles/hypr/workspace-groups.lua` coordinates ten numbered desktops across all
connected monitors using Hyprland's native Lua events. Meta+1–9/0 switches every
screen to the same desktop number while preserving the initiating screen and
pointer position. Meta+Shift+number moves the focused window to that desktop on
its current screen and follows it. Meta+wheel wraps through desktops 1–10.
Click a desktop number in any screen's Waybar to switch the whole desktop group.
Waybar clicks, scrolling over its workspace module and completed three-finger
swipes also synchronize the screens. During a swipe only the initiating screen
tracks the fingers; the others switch when the native workspace changes.
This groups separate native workspaces; a single tiled window cannot span screens.

On the reference desk Hyprland IDs 1–10 belong to the laptop, 11–20 to the lower
display and 21–30 to the upper display. Waybar labels them with their shared
desktop number and highlight the desktop visible on each screen. Only desktops
with a window somewhere in the group, plus the current desktop, are shown;
empty desktops remain available through shortcuts and swipes.
Existing windows are adopted on their present screen. When an
output disconnects, its windows join the matching desktop on their surviving
screen so they stay reachable. Redocking keeps those merged windows there;
new windows can be moved between screens with the existing directional controls.
Special workspaces remain independent. Other PCs allocate output slots as their
screens appear. Wallpaper selection still uses the underlying native IDs.

With the dock disconnected, the laptop panel remains enabled at its preferred
mode and 1.0 scaling. The external rotation and 120 Hz settings match only their
EDID descriptions. Undocking merges external windows into laptop desktops 1–10
and retires the missing screens' persistent workspace rules. All ten desktops
remain reachable through Meta+number, and the laptop bar follows its own windows.
The cursor plugin has no neighbouring output to cross to and uses ordinary
pointer motion. Reconnecting the dock restores its monitor modes and workspace
slots, including when connector numbers change.

The automated checks simulate workspace and Waybar unplug/replug behavior and
exercise the pinned WirePlumber default-selection hooks with and without the
RØDE. They do not replace a physical dock unplug/replug trial during an idle
session.

The app tray expands left inside Waybar with a short animation and a rotating
arrow. Hover opens it temporarily; Meta+Shift+T pins it open or closes it.
Only background-app icons live there; network, Bluetooth and audio controls keep
their existing launchers. `packages/waybar-tray/` extends the pinned Waybar's
native drawer with a keyboard-controlled arrow. No separate window, tray host,
or session service is started. Appearance and group configuration live in
`home/jeffreyc/desktop.nix`; the shortcut and existing bar visibility policy live
in `dotfiles/hypr/hyprland.lua`.

### App launcher

The app launcher shows short descriptions beside application names. Hidden
utilities remain available through shortcuts, commands, file associations and
context menus. `home/jeffreyc/packages.nix` preserves upstream desktop entries
while hiding Ark, Gwenview, qpdfview, the Packet Tracer PTSA handler, the CUPS web
interface, the NixOS manual, Rofi itself, uuctl, Wiremix and XTerm. Rofi's own
overrides live in the user application directory so its package wrapper cannot
give the original entries priority. **Print Settings** remains available for
printer administration. **Theme Selector** shows **Change system theme** and
opens the same system theme menu as Meta+Ctrl+T. Both launch `theme-menu` to choose
and apply the declarative desktop preset.
Waydroid and Aurora setup launchers are hidden in `home/jeffreyc/waydroid.nix`.
The activation helper preserves writable Android/game exports while hiding Aurora
Store and the recovery Instagram entry and adding descriptions to Instagram and
the existing EA App shortcut. No launcher service is added.

### Discord with Vesktop

Open **Vesktop (Discord chat)** from Rofi, or run `vesktop`. Rofi launches it
through UWSM on demand. Closing its window quits the client; no autostart or
additional session service is configured. Rich Presence integration is disabled.

`home/jeffreyc/programs.nix` uses Home Manager's Vesktop module with the pinned
Nixpkgs Vencord package. NoTrack disables Discord analytics, metrics and crash
reporting. Quick CSS hides Store, Nitro and sponsored Quest entry points and
known upsell elements. These are cosmetic filters; Discord UI changes can
require selector updates, and this does not block advertisements in shared
messages or embeds. Discord still receives account activity and messages.
Vencord is a third-party modification and its maintainers note that using it
violates Discord's terms: see the [upstream project](https://github.com/Vendicated/Vencord).

Client settings, Vencord settings and Quick CSS under `~/.config/vesktop/` are
managed by Home Manager; edit the Nix module and rebuild for persistent changes.
Login/session data remains writable and outside the repository and Nix store.
Vencord updates follow `flake.lock` and system rebuilds, with its own updater and
cloud settings sync disabled. Vesktop retains its sandboxed, isolated web renderer.

### Photo editing with darktable

Open **Darktable** from Rofi or run `darktable`. It starts on demand, with no
background service. `home/jeffreyc/programs.nix` installs the pinned application
and generates `~/.config/darktable/themes/desktop.css` from the shared theme.
The launcher selects this stylesheet and the system font through temporary
`--conf` overrides; other preferences, catalogues and edits remain user-managed.
Restart darktable after switching the desktop theme. Neutral image surrounds,
graphs and functional color swatches retain the native stylesheet's colors.
Gwenview remains the default image viewer.
The general focus-dependent window opacity still applies; keep darktable focused
while judging image colors.

Mesa's OpenCL driver in `modules/nixos/hardware.nix` supplies GPU processing.
The darktable launcher enables its Rusticl platform and defaults
`RUSTICL_ENABLE` to `radeonsi` for AMD GPUs; an existing environment setting takes
precedence. Other graphics hardware can fall back to CPU processing or use its
own configured OpenCL driver. Darktable's normal OpenCL preference remains writable.
The separate headless tools are unchanged. To test the AMD driver explicitly:

```bash
RUSTICL_ENABLE=radeonsi darktable-cltest --conf clplatform_rusticl=true
```

### Android apps and photo uploads

For Android applications and Dolphin's **Waydroid** sidebar entry, see
[Waydroid and photo uploads](waydroid.md). Android starts on demand; stop its
session when finished to release its memory.

### LibreWolf memory usage

LibreWolf defaults to unloading inactive tabs when system memory runs low.
Tabs remain in the tab bar and reload when selected; tabs playing media, using
picture-in-picture or WebRTC are excluded. The built-in unloader keeps its normal
inactivity rules, so it cannot guarantee protection against a rapidly growing
active page. The default is declared through package policies in
`home/jeffreyc/programs.nix`, without an extension or background service. Fully
quit and reopen LibreWolf after activation to load changed policies.

Open `about:processes` and sort by Memory to identify growing processes and their
tabs. Right-click an unused tab and choose **Unload Tab** to release its contents
while keeping the tab open. `about:unloads` shows automatic unloading priorities
and offers manual unloading. Unloading reloads the page on its next visit; save
unfinished work first. The `browser.tabs.unloadOnLowMemory` preference remains
editable in `about:config`; set it to `false` if automatic unloading causes
unwanted reloads. Linux memory detection can trigger unnecessary unloading,
which is why upstream disables this default.

### Power profiles and battery

Power mode defaults to Performance on AC, Balanced on battery, and Power Saver
at 20% battery or below. Clicking the mode cycles the available profiles; a
manual choice lasts until plugging in or unplugging resets automatic selection.
Restarting the policy service also restores automatic selection. Hardware without
a Performance profile falls back to Balanced. The existing power-profiles-daemon
applies the mode; `power-source-profile.service` listens to UPower events
without polling. Its declaration is in `modules/nixos/hardware.nix` and its policy
is in `scripts/power-source-profile.py`, included in portable bootstrap.
When this automatic low-battery mode begins, the same service caps the built-in
backlight at 30% on the existing brightness-key scale, preserving lower settings.
The cap applies once: brightness keys remain usable. On leaving low-battery mode
(including plugging in or choosing a manual profile), the previous brightness is
restored only if it still equals the automatically dimmed value. Originals survive
service restarts in `/run/power-source-profile`; reboot starts a fresh policy.
External monitor DDC controls are not included. No additional service is started.

Battery charging defaults to firmware conservation mode where the battery exposes
both `Long_Life` and `Standard` charging controls. On this Lenovo, conservation
mode targets roughly 75–80%, rather than an arbitrary configurable percentage.
The kernel also disables rapid charging when selecting `Long_Life`.
Before a longer trip, allow a normal full charge with:

```bash
battery-charge status
sudo battery-charge full
```

Restore protection with `sudo battery-charge protect`. A full-charge override
lasts until protection is selected again or the next boot; ordinary rebuilds do
not reset it. `full` uses normal charging, not rapid charging.
`modules/nixos/hardware.nix` installs this command and declares
`battery-charge-limit.service`, a root oneshot that runs at boot and initial
activation, then exits. It briefly waits for device discovery before checking
available controls. The firmware enforces the limit without a polling daemon.
The helper is `scripts/battery-charge.py`; it discovers batteries by capability
instead of hardcoding `BAT0`, skips unsupported hardware, and verifies mode
readback after changes. The same configuration is included in portable bootstrap.
Performance profiles and the existing low-battery brightness policy are separate.
The firmware preset's [Lenovo documentation](https://download.lenovo.com/pccbbs/pubs/ideapad_slim5_14_16/ug/html_en/en/intro_battery_mode_conservation.html)
describes the expected range; selecting the mode does not by itself verify the
actual charging cutoff on a particular battery. Before removing this policy,
select `full` to restore normal charging: firmware settings can persist
independently of NixOS generation rollback.

### Audio and pointer

The audio mixer is the [Wiremix fork](https://github.com/AldogPlays/wiremix), pinned through the `wiremix` flake
input and selected in `home/jeffreyc/packages.nix`. It replaces stock Wiremix
under the same command and desktop entry; Waybar and Meta+Shift+A open the fork
in the existing floating Alacritty window. PipeWire and WirePlumber are unchanged,
and no new background service is added. Update the fork deliberately with
`nix flake update wiremix`, validate, then rebuild.

On the reference desk, the RØDE AI-1 is preferred for both stereo playback and
mono microphone capture. `hosts/nixos/default.nix` installs the matching
WirePlumber user rules under `~/.config/wireplumber/wireplumber.conf.d/`.
They take effect when WirePlumber next starts; activation does not restart the
audio session. The live default selections are saved by `wpctl set-default`.
Wiremix can select another device, and ordinary fallback remains available
when the interface is unplugged. See [WirePlumber's ALSA rules](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html#rules).

The saved RØDE choice is a preference rather than a requirement for audio to work.
WirePlumber selects an available speaker and microphone when that interface is
absent and returns to it when it reappears, unless another device has been
selected deliberately in the meantime. The laptop's internal audio nodes remain
enabled.

The Ninjutso Sora 4K mouse has a device-specific Hyprland sensitivity of `-0.35`
in `dotfiles/hypr/hyprland.lua`; the ELAN mouse/touchpad devices retain their
existing settings. The override applies when the external mouse is connected,
independently of whether the laptop is docked.

The cursor hides after five seconds without pointer activity and reappears on
movement. This is Hyprland's native timeout, not a separate idle service.

### Wallpapers and screenshots

hyprmosaic draws each workspace's remembered random image from
`~/Pictures/Wallpapers`, including subfolders. Wallpapers slide with their
workspaces instead of changing underneath them. Assignments refresh every
quarter-hour, without wallpaper-based theme changes. Display-sized copies are
prepared ahead of time; originals remain untouched and outside Git.
A bounded 512 MiB cache in `~/.cache/workspace-wallpapers` reuses the exact
prepared images across logins and later refreshes, warming automatically on use.
See [workspace wallpapers](wallpapers.md) for implementation, cache limits,
supported formats, and troubleshooting.

The screenshot shortcut starts the on-demand `screenshot` helper declared in
`home/jeffreyc/packages.nix`, with its script in `dotfiles/hypr/screenshot.sh`.
Slurp outlines the hovered window (or the monitor when over a gap), lightly
dimming outside the selection. Click to capture that rectangle, or hold the left
button and drag to select a free area. Movements smaller than four logical pixels
on both axes still count as a click. Grim captures after the picker closes. Captures save to `Pictures/Screenshots` and copy to
the clipboard using wl-clipboard. A short SwayNC notification with a thumbnail
confirms both actions after capture; Escape stays silent. No editor is opened.
Print and Meta+Shift+S both start the same picker. Fn+Prt Sc sends Print;
the bare Lenovo screenshot hotkey can send Meta+Shift+S. No screenshot daemon
is started.
Window capture crops the visible screen, so overlapping content remains visible.
The picker chooses the smallest rectangle under the pointer; overlapping floating
windows can therefore be ambiguous. Slurp comes from pinned nixpkgs with the
small click-tolerance patch and headless tests in `packages/slurp/`; Grim uses
the pinned upstream package.

### Cisco Packet Tracer

Cisco Packet Tracer is declared from pinned nixpkgs (`cisco-packet-tracer_9`,
currently 9.0.1). Launch **Cisco Packet Tracer** from Rofi or run `packettracer9`.
Its package uses XWayland per application; no global Qt platform change or
background service is added. First launch may require Cisco's license acceptance
and Networking Academy sign-in.

Cisco requires a separately obtained installer. On a fresh installation, download
`CiscoPacketTracer_901_Ubuntu_64bit.deb` from
[Cisco's Resource Hub](https://www.netacad.com/resources/lab-downloads) into
`~/Downloads` before running bootstrap. Bootstrap checks its SHA-256 against the
pinned package and imports it automatically; the same single bootstrap command
then installs it with the rest of the desktop. The binary and Cisco credentials
are never committed. When updating the pinned package, use its exact installer
version. For an existing checkout without bootstrap, import the file once with:

```bash
nix-store --add-fixed sha256 ~/Downloads/CiscoPacketTracer_901_Ubuntu_64bit.deb
```

## Desktop integration

### Theme selection

Meta+Ctrl+T opens the existing Rofi launcher as a theme menu, with **Active**
beside the running system's theme. Escape and selecting the active theme leave
the configuration alone. Choosing another opens a floating Alacritty terminal
for build output and normal sudo authentication. The rebuild applies the current
saved configuration, including other edits. It does not commit, push or reboot.

`scripts/theme-menu.py` is installed as the on-demand `theme-menu` command through
`home/jeffreyc/desktop.nix`. It uses the existing Rofi styling and Alacritty;
there is no background service. The shared NixOS desktop module writes the theme
identity into each generation, which the menu reads through `/run/current-system`.
See [theme settings](../theme/README.md#choose-a-theme) for persistence, wallpaper
preferences and application refresh behavior.

### Applications and appearance

Printing uses CUPS for LibreWolf, qpdfview, and other applications' print dialogs.
Press **Ctrl+P** in LibreWolf or a document viewer, select the printer and print;
LibreWolf's **Save to PDF** destination also works without a physical printer.
Turn on a network printer and connect this PC to the same local network for
automatic discovery. Open **Print Settings** from Rofi (`system-config-printer`)
to add a printer manually, choose its default settings, or view/cancel jobs.
PDFs open in qpdfview from Dolphin; use **Ctrl+P** there to print them.

`modules/nixos/hyprland.nix` enables socket-activated CUPS, the boot-started Avahi
discovery service and cups-browsed queue discovery. The Print Settings GUI starts
on demand, with its administration helper activated through D-Bus. Avahi opens
UDP 5353 for mDNS; CUPS keeps its local-only listener and printer sharing stays
disabled. Modern IPP/AirPrint network printers use driverless printing. Older or
USB-only models may need a model-specific driver declared in
`services.printing.drivers`; no manufacturer driver bundle is preinstalled.
These settings are included in portable bootstrap.

Steam is installed through `programs.steam` in `modules/nixos/hyprland.nix`.
Launch **Steam** from Rofi or run `steam`, then sign in. The NixOS module supplies
the runtime, 32-bit graphics/audio support and controller permissions. Steam
downloads Valve's Proton when needed for Windows games; compatibility can be
selected per game under **Properties → Compatibility**. No extra gaming
overlay, tuning daemon or Steam-specific firewall opening is configured.

Lutris is declared in `home/jeffreyc/packages.nix` from pinned nixpkgs, including
its NixOS-compatible game runtime. Launch **Lutris** from Rofi or run `lutris`.
It starts on demand; game installations, downloaded runners and account sign-ins
remain user-managed.

Home Manager creates and registers `Desktop`, `Documents`, `Downloads`, `Music`,
`Pictures`, `Public`, `Templates`, `Videos`, and `Projects`, plus writable
`Pictures/Screenshots` and `Pictures/Wallpapers` subfolders. The screenshot helper
uses the XDG Pictures directory and saves under `Screenshots`.

Native desktop defaults in `home/jeffreyc/default.nix` select LibreWolf for web
links and HTML; qpdfview for PDFs; Dolphin for folders; and Alacritty through
`xdg-terminal-exec` for compatible terminal-launching apps. `codex://` links
remain assigned to ChatGPT/Codex. Keep changes declarative rather than editing
the managed `mimeapps.list` in a GUI. Existing unmanaged files are preserved with
Home Manager's backup suffix during the first activation.

The existing GTK/Hyprland portals, polkit agent, and UDisks2 provide file dialogs,
screen sharing, authentication prompts, and removable-drive support. No desktop
bundle or automounter is added. Media-player, mail, and general GUI editor
choices remain open; they are not silently filled by extra packages.

`theme/common.nix` defines the shared Monaspace Neon font and point size.
Alacritty, Rofi, Waybar, SwayNC, GTK defaults and KDE UI fonts consume it. CSS uses
points rather than pixels, without changing display scaling. Web content and
applications with their own font settings are not forcibly overridden.
Cursor settings apply to Hyprland, GTK, Qt/KDE and X11. Latte uses the contrasting
Catppuccin Mocha Dark pointer; Monochrome uses DMZ White from `vanilla-dmz`.
Each preset supplies its package, name and size to the existing desktop modules.
Shared shell geometry lives in `theme/common.nix`; adapters reference
matching borders, corner radii, gaps and padding instead of keeping separate copies.

Frosted glass applies to normal application windows and Rofi.
`theme/common.nix.material` controls their shared background opacity and
Hyprland blur settings. `material.focusedOpacity` makes focused windows fully
opaque; unfocused windows use `material.unfocusedOpacity` (95% opacity), and
fullscreen is fully opaque. Rofi's backplate uses `material.opacity` (90%).
Explicitly marked modal dialogs and recognized LibreWolf/Firefox picture-in-picture
windows stay fully opaque; recognized PiP windows float at a compact initial size,
without forcing position or pin state. Manual resizing remains available; a
config reload reapplies the default once. PiP matching uses the browser class and
exact English `Picture-in-Picture` title; other apps/localizations may need
additional verified identifiers. Unmarked dialogs cannot be identified
generically by this rule.
Hyprland affects the whole surface, including text, images and video; native
terminal alpha stays at 1.0 to avoid double transparency. Waybar and SwayNC use a
fully opaque shared theme background, independent of window focus. The login screen
stays opaque.
Windows have 1px borders: the shared focus color when active and muted border
color when inactive. The notification-center frame uses the same muted outline,
background, font and rounding as Waybar tooltips, keeping its roomier control
spacing. Both Rofi menus share the same background, text, selection colors, font,
spacing and focused-window border. **Active** is identified by its label without
a different row color; useful control outlines and separators remain. This is
matte blur, without glossy gradients or refraction.
The [generation rollback command](maintenance.md#recovery) restores the previous
active configuration. Reverting the repository is a separate Git change; keep
the source consistent with the chosen generation before rebuilding.

## GTK, login and lock screens

Plymouth provides the graphical encrypted-disk password prompt before login.
`modules/nixos/hyprland.nix` enables its native NixOS boot integration and generates
a plain theme from `theme/`; `dotfiles/plymouth/theme.script` renders the
prompt and masked input. It uses the shared font and the same field dimensions,
thin outline and rounding as hyprlock. Plymouth starts during boot and exits
when boot completes; it adds no desktop background service. Existing disk
encryption, passphrases and initrd style are preserved, including on portable
hosts. Escape switches to boot details. Plymouth takes effect on boot after
activation; successful graphical unlocking is not yet verified.

GTK3 uses `adw-gtk3` for widget structure with generated theme colors;
GTK4/libadwaita keeps its native layout with generated color variables. Both
adapters live in `home/jeffreyc/desktop.nix`. The shared appearance preference
selects the matching GTK3 variant and GTK/Home Manager light/dark settings;
it remains light for Latte. No GNOME session,
theme daemon or independent Catppuccin palette is installed. Legacy GTK2 colors,
sandboxed apps without access to host configuration, and apps overriding their
own styling are not covered by these adapters. Reopen apps that cache styling.

SDDM remains the login manager. `modules/nixos/hyprland.nix` configures the pinned
minimal `where-is-my-sddm-theme` layout using the shared colors, font and cursor.
The username and session are visible; type your password and press Enter.
F1 shows its keyboard help, F2 cycles users and F3 cycles sessions. Its power
shortcuts are F10 suspend, F11 power off and F12 reboot. The new greeter takes
effect when SDDM next starts, normally on your next boot; do not restart the
display manager mid-session just to preview it.

Meta+L runs hyprlock with a solid, opaque theme background, username and
thin-bordered password field. No background screenshot, blur or transparency is
configured. Live session-lock xray remains disabled.
Authentication is unchanged. The generated config is in `~/.config/hypr/hyprlock.conf`;
NixOS declares its PAM service for normal password authentication. No auto-lock
timer, idle daemon or authentication grace period is added. Test unlocking at a
convenient time; configuration checks do not prove a successful password unlock.

## Dolphin

Meta+E explicitly opens a new window at the current account's home directory,
instead of restoring the last folder. The command lives in
`dotfiles/hypr/hyprland.lua`; ordinary file/folder opening keeps its supplied path.
Home Manager's activation in `home/jeffreyc/desktop.nix` also disables tab
restoration and selects Home for fresh launches from the menu or command line.
It backs up `dolphinrc` once and changes only those two startup keys.

`home/jeffreyc/desktop.nix` generates `kdeglobals` and the `JeffreyTheme.colors`
scheme from `theme/`. The KDE Qt platform plugin and Breeze widget style supply
native controls; Breeze icons are exposed from Dolphin's existing dependencies.
This does not install a Plasma session, System Settings, Konsole, or an indexer.
It also sets the platform/style for other Qt applications, not just Dolphin.

Open Terminal (Shift+F4) uses Alacritty at the viewed location. Dolphin's F4
embedded terminal requires Konsole's separate component and is intentionally not
added. Other Dolphin preferences, view history, and Places bookmarks remain
writable and unmanaged; startup, default apps and theme colors are declarative.
KIO supplies file/trash support and extras. Qt's `kimageformats` adds HEIC/HEIF,
AVIF, JPEG XL, RAW and other image readers; `kdegraphics-thumbnailers` adds PDF/RAW
previews, and `ffmpegthumbs` adds video previews. Toggle **Show Previews** with F12;
individual types remain configurable in Dolphin's preview preferences. Existing
per-folder view settings are preserved.

Gwenview is the default image viewer and quick editor, using the same KDE
theme. It supports crop, resize, rotate, flip, annotation and basic adjustments;
save a copy when preserving an original. It launches on demand, not as a daemon.

qpdfview is the default PDF viewer. It is built against the same pinned Qt6
toolkit and uses the selected KDE palette, Breeze controls, icons, and fonts
without a separate theme configuration. Open PDFs from Dolphin or run
`qpdfview`. It starts on demand and adds no background service.

ONLYOFFICE Desktop Editors is the default editor for DOCX, DOC, ODT and RTF.
Open a document from Dolphin, choose **ONLYOFFICE** in the app
launcher, or run `onlyoffice-desktopeditors`. Its single desktop package also
includes spreadsheet and presentation editors. It works with local files offline
without an account and starts on demand without a background service.
Microsoft's DOCX, XLSX and PPTX are its native formats; see the upstream
[format explanation](https://community.onlyoffice.com/t/make-the-open-document-format-odf-a-first-level-citizen-in-onlyoffice/18930/3)
and [desktop guide](https://helpcenter.onlyoffice.com/desktop/getting-started).
Older DOC files are converted for editing; save as DOCX. Complex layouts and
missing document fonts can still affect fidelity, so check important documents
in Word before sharing. Existing documents and application preferences remain
user-managed. The editor uses its built-in appearance rather than the shared
desktop palette; qpdfview remains the default PDF viewer.

Ark supplies native **Extract** and **Compress** context-menu actions and is the
default archive viewer. Use **Extract here** or **Extract to…** to unpack files;
select files/folders and use **Compress to…** to create an archive. These are
Ark's upstream service menus, not custom shell actions. Ark shares the KDE
theme. The maintained 7-Zip backend provides both `7zz` and the `7z` name required
by this pinned Ark version. ZIP and tar formats use Ark's native libraries;
7z uses the external backend. No archive daemon is added. Archives from untrusted
sources should be extracted into a fresh destination, not over important files.

After activation, use a newly started Dolphin process for the new Qt environment.
Existing windows are not force-closed. A fresh login also picks up the declarative
Qt session settings.

## Shell workflow

Starship supplies a minimal single-line Bash prompt: directory, Git branch/status
when applicable, and an arrow that changes color after a failed command. Its
settings are declared in `home/jeffreyc/programs.nix`, using shared theme roles;
the generated file is `~/.config/starship.toml`. Open a new terminal after
activation to initialize it, or run `exec bash` at an idle shell prompt. No new
background service is added.

### Shell conveniences

Interactive Bash uses ble.sh for syntax highlighting, completion menus and
grey/italic suggestions from local history and normal shell completion. Tab
performs ordinary command/path completion; Right Arrow accepts the visible
suggestion at the end of the line. Enter executes
only the accepted text. Ctrl+R still searches history. Suggestions are not AI
and do not send your history anywhere.

Keep typing `ls` and `ll`: interactive aliases use eza for directory grouping,
file-type icons, readable file colors and Git status in long listings. Icons
appear only in terminal output, using the existing Nerd Font fallback.
`ls --tree --level=2` gives a compact directory-tree peek without a new command.
`command ls` bypasses the alias for exact GNU behavior; scripts are unchanged.
Eza is not completely flag-compatible with GNU ls.

Git uses delta automatically for paged diffs, show/log and blame, including line
numbers and word-level change emphasis. Normal pager controls still work (`q`
to quit, `/` to search); `n`/`N` navigate diff sections. `git --no-pager diff`
bypasses it. Piped Git output remains normal Git output. These settings live in
`home/jeffreyc/programs.nix`; generated configuration uses the shared theme.
Open a new terminal after activation; no daemon or shell migration is involved.

## Graphical Codex

The official ChatGPT desktop app includes graphical Codex and is installed
alongside the CLI. Open **ChatGPT** from Rofi or run `chatgpt`, then sign in with
your ChatGPT account. Both clients are pinned through the unstable flake input.

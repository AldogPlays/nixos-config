# System context and decisions

This is a reference for the intended system and choices that affect future work.
The Nix configuration is authoritative for exact values. This document does not
establish what is currently activated or running; inspect the host when needed.
Git history records changes. The bootstrap observations in `audit.md` are historical.

The reference host was checked against the checkout on 2026-10-29: both selected
and running kernels were 7.2.10, the active desktop theme was Latte, and no system
or user services were failed. The live compositor service had `OOMPolicy=continue`
in `session.slice`; `app.slice` had memory-pressure and swap killing enabled.
Zswap was enabled with zstd and a 20% pool limit. Declared Nix build limits were
two concurrent builds and two cores per build. These observations are a dated
verification, not a guarantee about later sessions.

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
new project revision to update that snapshot. See the [installation guide](installation.md)
for authentication, supported layouts and the remaining deployment test, and
[maintenance](maintenance.md) for recovery.

The official ChatGPT desktop app provides graphical Codex alongside the Codex CLI.
Both are declared from the pinned unstable input; the Linux desktop launcher is
`chatgpt`. This uses nixpkgs' adaptation of the official application binary.

Cisco Packet Tracer is supplied by pinned nixpkgs, launched as `packettracer9` or
through its desktop entry. The package selects XWayland locally. Cisco's matching
installer is a separately downloaded input: bootstrap verifies and imports it
from `~/Downloads` when absent from the store. See the
[desktop guide](desktop.md#cisco-packet-tracer) for the exact version and manual
import command; binaries, license state and Cisco credentials stay outside the
repository.

Joplin Desktop is declared in `home/jeffreyc/packages.nix` from the pinned unstable
input for a version newer than 3.7.0; stable nixpkgs supplies 3.5.13.
It launches with Meta+J, from the app menu or `joplin-desktop`; no autostart service or sync
account is configured. Notes and application preferences remain user-managed.

Darktable is declared in `home/jeffreyc/programs.nix` from pinned stable nixpkgs.
The `darktable` command and desktop launcher select a generated native GTK stylesheet using
temporary `--conf` overrides. Interface colors and typography follow the shared
theme; image surrounds, graphs and functional color swatches retain native
colors for photo assessment. Catalogues, edits and other preferences stay
user-managed. It starts on demand, with no new service or default image association.
Mesa's separate OpenCL output supplies the compute driver without a ROCm stack.
The application wrapper enables its Rusticl platform and defaults the AMD device
selector for this laptop, while preserving an explicit environment override.
The separate `darktable-cli` and `darktable-cltest` commands remain upstream tools;
the GUI launcher's theme and environment overrides do not wrap those commands.
On 2026-10-29, darktable-cltest compiled its kernels and initialized the Radeon
860M through Rusticl successfully; this does not validate every photo operation.

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

Modrinth App is declared in `home/jeffreyc/packages.nix` from pinned nixpkgs,
including its Java runtimes and game libraries. Launch it from Rofi or run
`ModrinthApp`; it adds no background service. Minecraft instances, mods and
account sign-ins remain user-managed.

The kernel selection is `pkgs.linuxPackages_latest` from the stable input. Recent
hardware support is a consideration when reviewing that choice, but a specific
requirement for this kernel has not been established.

Waydroid is declared in `modules/nixos/waydroid.nix` using the pinned nftables
package and Nix-managed VANILLA Android images. Its root D-Bus controller runs
on demand. A guarded initialization oneshot prepares images during
activation or boot; Home Manager owns one on-demand Android session.
Aurora Store is a pinned, normal Android app installed through `waydroid-setup`.
Android apps, permissions and accounts remain user-managed data. No Google
services, root-management, camera or location-forwarding stack is installed.
The running Lenovo kernel has Binder IPC and Binderfs built in, so this setup
does not require a different kernel.

`~/Waydroid` provides writable access to Android's shared media storage, including
Pictures and DCIM, through an on-access bindfs mount. A root preparation oneshot
creates missing directories; bindfs maps desktop access and preserves Android
media ownership for new files. Home Manager adds **Waydroid** to Dolphin Places
through a preserving XBEL helper, backing up the original first. Existing
bookmarks and Dolphin state remain user-managed.
An event-driven systemd path unit watches direct changes to Pictures, DCIM and
Download and runs an Android media-index scan only while the container is running.
This handles host writes that bypass Android's emulated-storage notifications;
existing nested directories require a manual scan.
Images and the Aurora APK are pinned in `packages/waydroid/default.nix`; no APKs,
Android images or account data are committed to Git. See [Waydroid](waydroid.md)
for setup, stopping Android, updates and runtime validation limits.
The vendor image includes a small YV12 layout adapter for Instagram's native
graphics crash, preserving GPU acceleration. It corrects video-plane metadata
around the pinned minigbm backend. The repair lives in the immutable vendor
image so switching generations can remove it; Android user data stays separate.
The Android controller restarts when its image derivation changes. Stop Android
before image updates. Native buffer tests and Instagram startup were verified
on 2026-10-29, and the owner confirmed normal video/Reels playback. A complete
photo upload remains a manual check.

The reference laptop uses a separately signed patched **Instagram**,
package `com.instagram.android.piko`.
`packages/instagram-reels/` contains local bytecode patches and a pinned build
command; only Piko's generic package-cloning patch is reused. Original APKs,
signing keys and account data remain outside Git and the Nix store. The clone
has no normal Play/Aurora update target, its APK-install request operation is
denied, and Aurora excludes the original Instagram from updates. Updates are
manual, with source/input review and runtime checks. The clone does not globally
block every Reel/video or alternate feed entry point. Home and Reels navigation
are removed while Direct, Search, Profile and Create are retained.
Direct is the first tab and default startup destination.
The original package is disabled for recovery with its data retained and its
desktop entry hidden; the patched app is the sole visible Instagram launcher.
Android's saved appearance is light, with the app visually verified in light mode.
Home Manager reapplies the original launcher's `NoDisplay` flag through
`scripts/waydroid-launcher-policy.py`, preserving Waydroid's writable export.
Keep the existing tiling behavior; no phone-shaped aspect-ratio lock is requested.
See the [package guide](../packages/instagram-reels/README.md)
for supported inputs, exact validation limits, recovery and fresh-install steps.

Waydroid mouse-wheel and touchpad scrolling are reduced by a per-window Hyprland
rule in `dotfiles/hypr/hyprland.lua`. Android media volume remains adjustable
Android user state; it was set to 12/15 on the reference laptop on 2026-10-29.
The host speaker level was already 100%; no global amplification was added.

The systemd-boot menu is hidden for normal startup; hold Space during firmware
startup to open it and select an earlier generation. A persistent EFI menu-timeout
override takes precedence over the declared timeout, so clear an old override
with `sudo bootctl set-timeout ''` after activating the configuration. This does
not change disk-unlock or login authentication.

Plymouth's graphical disk-unlock prompt is declared in the shared desktop module,
using the native script plugin and a small theme generated from `theme/`.
`dotfiles/plymouth/theme.script` only renders the prompt and password mask;
the existing initrd/password agent continues to unlock the disks. It preserves
the initrd style, LUKS devices, keys and passphrases. The NixOS module supplies
the `splash` kernel parameter and boot/shutdown units, without a desktop daemon.
Escape switches to boot details; earlier generations remain available through
the existing boot menu. Actual boot rendering and successful graphical unlocking
remain unverified pending an actual boot/unlock test.

Root is LUKS-encrypted Btrfs, mounted at the top level. `/home` and `/nix` are
separate subvolumes sharing its capacity. `/boot` is a separate EFI partition;
swap is a separate encrypted 8.8 GiB partition. There is no declared resume device,
snapshot policy, or Btrfs compression setting. Recovery tooling requires a design
appropriate to this layout. Weekly Nix garbage collection retains according to
`--delete-older-than 30d`; it is not a personal-data backup.

The shared core module enables zswap when the host has disk swap and does not
use zram. It caches swapped pages with zstd compression in a bounded, on-demand
RAM pool, then falls back to the existing swap device. Kernel parameters cover
boot and NixOS's sysfs setters apply the same settings live; no new resident
daemon is added. The pinned `boot.zswap` module still configures a `zpool` sysfs
attribute removed by the selected kernel, so `modules/nixos/core.nix` uses the
supported kernel-parameter and sysfs options directly. Hosts without disk swap
keep their existing layout rather than gaining a swap partition or file.

Nix build concurrency is limited in the shared core module to leave memory and
CPU headroom for desktop applications. Packages that honor Nix's core setting
use the per-build limit; these settings do not impose a hard memory cap. Large
source builds can take longer. Command-line overrides remain available for an
intentional foreground build.

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

## Security posture

The local review on 2026-10-31 covered effective NixOS settings, live IPv4/IPv6
input rules and listeners, sudo/account configuration, lock-screen PAM, Nix
trust/sandbox settings, repository history and local secret-file permissions.
Gitleaks 8.30.1 found no matches across all 44 commits reachable at the time.
This is a scoped review, not a guarantee that credentials or vulnerabilities
cannot exist.

The live input firewall matched the declared policy: SSH was disabled, printing
and desktop application endpoints were loopback-only, and mDNS was the deliberate
LAN discovery opening. Tailscale maintained its own networking rules; MagicDNS
was enabled, with Tailscale SSH and advertised routes disabled. Android DNS/DHCP
listeners were confined to the Waydroid bridge; that bridge is deliberately
trusted by the host. Sudo required a password, the Nix daemon trusted only root,
and build sandboxing was enabled. The GitHub credential file, Android signing
key and Tailscale state had restrictive access and remained outside Git.
Forwarding uses the existing Tailscale/Waydroid integration; this input-rule
review does not establish isolation between every routed network.

Manual locking remains intentional; no automatic idle lock was added. Independent
personal-data backups and a restore trial remain a separate recovery requirement.
The review did not perform external penetration testing, audit every dependency
against vulnerability databases, or establish successful physical lock/unlock.

The reference host trusts the homelab Caddy root CA through
`security.pki.certificateFiles` in `hosts/nixos/default.nix`. Its public certificate
is stored in `hosts/nixos/certificates/hermes-root-ca.crt`; no private key belongs
in the repository or Nix store. This host-specific trust is not inherited by
portable bootstrap installations. Replacement certificates require fingerprint
verification before changing the trust anchor.
The pinned LibreWolf NSS library uses p11-kit for its root store, so this CA
does not require a separate browser import policy. On 2026-11-01, a fresh
LibreWolf 158 profile reported the CA trusted for TLS and opened the homelab
login page with certificate verification enabled and no saved exceptions.
An already running browser may need a normal restart to refresh its trust store.

## Desktop components

Hyprland handles cursor hiding with its native inactivity timeout, without an
idle daemon. Meta+K uses Dwindle's `togglesplit` for the focused tile's parent
split, with split preservation enabled; it is not a whole-workspace rotation.

On 2026-10-20 at 14:47, the kernel reported exhausted RAM and all 8.8 GiB of
swap, then killed a browser content process using about 5.7 GiB resident RAM
and 5.0 GiB swap. It was inside `wayland-wm@hyprland.desktop.service`;
the service's effective `OOMPolicy=stop` then ended the whole graphical session.
This establishes the latest logout's cause, not every earlier reported freeze.
The Home Manager drop-in under `systemd/user/wayland-wm@.service.d/` sets
`OOMPolicy=continue`; a user-manager daemon reload applies it without restarting
Hyprland. Keyboard application shortcuts, Waybar's TUI launchers, and Rofi's
run commands use the existing `uwsm app --` to place newly launched apps in
separate units. Rofi itself and short-lived compositor helpers stay direct.
Existing app processes retain their original units until normally closed;
they are not forcibly moved or restarted. This limits session-wide fallout,
but does not cure a browser memory leak or guarantee responsiveness after all
memory is exhausted.

The existing systemd-oomd monitors the user manager's `app.slice` for sustained
memory pressure and nearly exhausted swap. It can terminate an entire application
unit, including unsaved work, to release memory before prolonged system stalls.
Hyprland and core session services in `session.slice` are outside this monitoring
scope. This is declared in `modules/nixos/core.nix` and starts through systemd;
no second OOM daemon or arbitrary per-app RAM cap is installed. Pressure thresholds
measure time stalled on memory, not the percentage of RAM occupied. This policy
does not guarantee recovery from every allocation burst or kernel OOM.

SwayNC keeps only its title, do-not-disturb switch and notification list. Its
fixed-height panel, compact spacing, small icons and flat controls are declared
in `home/jeffreyc/desktop.nix`, consuming shared theme colors and font from
`theme/default.nix`. Panel and popup backgrounds are fully opaque, matching
Waybar; their layer surfaces do not request blur. The panel and Waybar tooltips
share the main background, muted border, font and rounding. The larger panel
retains its control spacing; theme-colored focus outlines remain on keyboard-focused controls.
Notification cards and controls have thin outlines, with explicit keyboard-focus indication.
Clear All uses explicit label colors without GTK's additional dimming; when
disabled on an empty list, it keeps readable muted text on the alternate background.
The panel and popups use the shared outer tile gap below the usable screen edge
and from the right edge, aligning their outer borders with tiled windows.
Layer-shell accounts for Waybar's reserved space; popup CSS supplies the same
inset as the panel margins. Waybar tooltip CSS offsets GTK’s fixed box margins
to provide the same right-edge inset and align the top with the tile border;
GTK retains its native placement around the hovered module.
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
| Printing | CUPS, cups-browsed, Avahi; Print Settings | `modules/nixos/hyprland.nix`; application Ctrl+P, `system-config-printer` for administration |
| Network controls | NetworkManager, wlctl | Click Waybar network or Super+Shift+N to open wlctl in Alacritty |
| Bluetooth controls | BlueZ, Bluetui | Click Waybar Bluetooth or Super+Shift+B to open Bluetui in Alacritty |
| Authentication prompts | polkit, hyprpolkitagent | NixOS desktop module and Home Manager session service |
| Audio | PipeWire, WirePlumber; the Wiremix fork, wpctl | Click Waybar volume or Super+Shift+A for Wiremix; media keys use desktop-feedback around wpctl |
| System monitor | btop in floating Alacritty | Meta+Esc or click the battery; `home/jeffreyc/programs.nix` supplies its shared-theme config |
| Portals | Hyprland and GTK backends | Hyprland's NixOS module supplies its portal; GTK is added explicitly |
| Screenshots and clipboard | slurp, grim, wl-clipboard | Print or Meta+Shift+S starts `screenshot`; `home/jeffreyc/packages.nix`, `dotfiles/hypr/screenshot.sh`; no daemon |
| Brightness and media | brightnessctl, playerctl, SwayOSD | desktop-feedback preserves the brightness curve; Home Manager starts swayosd.service with the graphical session |
| Fonts | Monaspace Neon, Nerd Font symbols, Noto, Noto Emoji | NixOS desktop module and application settings |
| Wallpaper | hyprmosaic, wallpaper-only backport | Native plugin draws workspace-linked images; Lua events/timer trigger preparation |

Firmware updates, power profiles, and battery state are supported by fwupd,
power-profiles-daemon, and UPower. `power-source-profile.service`, declared in
`modules/nixos/hardware.nix`, runs the repository's Python policy at graphical boot.
It is wanted by `graphical.target`, since the packaged power daemon starts after
`multi-user.target`; attaching the helper to that earlier target creates a boot
ordering cycle. Activation can reload this dependency without restarting the
helper and resetting an intentional manual profile.
It listens for UPower and power-profile D-Bus changes without polling. Automatic
selection is Performance on AC, Balanced on battery, and Power Saver at or below
20%. A manual profile change stays in effect until the power source changes;
service restart also resets it. Hosts without Performance fall back to Balanced.
Entering automatic low-battery Power Saver caps sysfs backlights at 30% on the
existing brightnessctl fourth-root scale. This is a one-time cap, preserves
already lower settings, and permits subsequent manual brightness changes. Leaving
the automatic low-battery condition restores the previous value only for backlights
still at the dimmed value. Runtime state in `/run/power-source-profile` preserves
originals across service restarts; it does not survive reboot. The existing
system policy service handles this without polling or an additional daemon.
External monitor DDC brightness is outside this policy.
The daemon's native battery-aware hardware tuning remains enabled: it adjusts
tuning within the selected profile, rather than replacing this selection policy.
The service reconnects after backend failure by restarting; it neither replaces
the existing power daemon nor adds TLP or another hardware tuning stack.

Battery conservation is a separate firmware setting, independent of performance
profiles and the low-battery policy. The shared hardware module installs the
on-demand `battery-charge` command and one root `battery-charge-limit.service`.
That oneshot selects `Long_Life` at boot and initial activation, then exits; the
firmware enforces its preset without a resident controller or polling loop.
The helper discovers batteries exposing both `Long_Life` and `Standard`, verifies
the selected mode after writing, and skips unsupported hardware on portable hosts.
It uses the kernel's `charge_types` interface, which switches conservation and
rapid charging together instead of potentially enabling both through legacy
controls. The Lenovo preset is documented around 75–80%; the actual cutoff still
requires a plugged-in charging observation. `battery-charge full` selects
`Standard` for travel, and `protect` restores conservation; changes require sudo.
Full charging lasts until `protect` or reboot. The oneshot remains active after
exit and is not restarted on definition changes during rebuilds, preserving an
intentional override. Read-only `status` and usage are documented in the
[desktop guide](desktop.md#power-profiles-and-battery).

Waybar uses its native power-profiles-daemon module for live profile display and
click-to-cycle. Workspaces are the only left-side module; the tray starts the
right group. Status modules show accented icons with connection details and
percentages in tooltips, including Bluetooth without its old device-count label.
The six status modules share a minimum icon width, horizontal padding and gap;
the tray arrow uses the same width and padding. Control icon accents and shared
shell geometry come from `theme/default.nix`. The 12-hour clock has no calendar
dropdown or tooltip.
Calendar/Nextcloud integration remains a future choice. Existing Hyprland
visibility events and TUI launchers stay in use.

The app tray expands left within Waybar using its native animated drawer.
Hover opens temporarily; Meta+Shift+T pins it open or closes it. The existing
Lua visibility policy keeps the bar visible while pinned on an empty workspace.
`packages/waybar-tray/` adds a small signal-controlled arrow to the native drawer;
it reuses the existing StatusNotifier tray, menus and process without a separate
window or service. Wi-Fi, Bluetooth, volume and battery display icons only, with
details in tooltips. The plugged-in/charging battery uses a battery-with-lightning
icon in the shared success color, distinguishing it from Performance mode's
standalone lightning bolt. Appearance remains driven by the selected theme roles.

Wiremix comes from the public `AldogPlays/wiremix` fork on
`codex/ui-match`, pinned in `flake.lock` and following the system nixpkgs.
`home/jeffreyc/packages.nix` selects the fork instead of stock Wiremix, retaining
the `wiremix` command and desktop entry for both existing floating launchers.
The fork's single-page audio sections and contextual controls replace its UI;
PipeWire/WirePlumber and their startup remain unchanged. No local checkout path,
imperative installation, or extra service is required on a new machine.

The TUI controls, including btop's CPU/memory/process/battery monitor, are launched on demand; the
network/Bluetooth/audio backend services remain enabled. Their dedicated
Alacritty app IDs float through `dotfiles/hypr/hyprland.lua`. Keyboard and Waybar
launch commands bind unmodified Escape to Alacritty's Quit action for these
windows only, closing even an active TUI prompt. No extra service is involved.
nm-applet, Blueman, and pavucontrol are no longer declared as front ends.
The monitor uses the same UWSM launch and Escape-to-close behavior, with no new
background service. Its dedicated Alacritty class is `system-monitor`.

Tailscale is declared in `modules/nixos/core.nix`: the system `tailscaled` daemon
and CLI, with interactive authentication kept outside the repository and store.
Tailscale DNS and MagicDNS are required; preserve them when diagnosing network
reliability. The reference tailnet supplies a DNS resolver managed outside this
repository. Investigate resolver/tunnel timeouts rather than bypassing this DNS
setup with Wi-Fi or public resolvers.
No additional GUI, Tailscale SSH, subnet routing, or exit-node setup is declared.

LibreWolf's package policies default downloads to the XDG Downloads folder and
disable the per-download location prompt. They also enable automatic low-memory
tab unloading by default; the pinned Linux build disables it. The preference is
unlocked, allowing a profile override. Home Manager supplies the browser through
`programs.librewolf` in `home/jeffreyc/programs.nix`; existing browser profiles
remain unmanaged. This uses the browser's built-in tab unloader without an
extension or service. After activation, fully quit and reopen LibreWolf to load
the policies. Unloading inactive tabs can reduce memory pressure, but cannot
guarantee recovery from a rapidly growing active tab.

Printing is enabled in the shared NixOS desktop module, including portable hosts.
CUPS starts through its socket for application print dialogs. Avahi and
cups-browsed start at boot to discover network printers and expose local queues
across applications. Avahi enables IPv4 `.local` resolution and opens mDNS UDP
5353; CUPS remains local-only with sharing disabled. Print Settings
(`system-config-printer`) is an on-demand GTK administration/queue GUI, with its
D-Bus/udev integration enabled through the NixOS program module. CUPS supplies
its existing polkit helper, so no new custom authorization rules are needed.
Prefer driverless IPP/AirPrint; add manufacturer drivers only for a confirmed
model that needs them. Individual printer queues/defaults remain user-managed;
the general printing stack is reproducible. On 2026-10-21, activation discovered
an HP OfficeJet Pro 8030 series over Wi-Fi and created an enabled, accepting queue.
The printer answered IPP capability queries and accepted driverless raster job
validation; the local CUPS queue accepted PDF job validation, and Print Settings
opened successfully. This did not send a document or establish successful paper
output.

Desktop integration lives in `home/jeffreyc/default.nix`: managed XDG user
directories (including existing Projects), explicit MIME defaults for
LibreWolf/Dolphin and the `codex://` handler, and `xdg-terminal-exec` selecting
Alacritty. The terminal selector is an on-demand command, not a daemon. Standard
folders and Pictures/Screenshots/Wallpapers are created without moving existing
data. MIME configuration that predates Home Manager is backed up rather than
discarded. Gwenview supplies image viewing and quick editing. Dedicated media
player/mail/office/general GUI editor choices remain pending; do not install a
bundle to fill those roles.

The application menu uses declarative desktop-entry overrides in
`home/jeffreyc/packages.nix` for short descriptions and hidden utility entries.
Upstream MIME associations, actions and launch arguments are preserved. Rofi's
own overrides are also linked into the user application directory, ahead of the
original entries that its wrapper prepends to `XDG_DATA_DIRS`. The
writable Android/game exports are updated by the existing activation helper;
Waydroid preserves its custom visibility and description fields on refresh.
**Theme Selector** launches the existing `theme-menu` command, shared with
Meta+Ctrl+T, to choose and apply the system theme. The upstream Rofi-only picker
is replaced in the application menu. No launcher service is added.

Meta+E explicitly passes the account's home directory to a new Dolphin window.
A preserving Home Manager activation sets Home and disables tab restoration for
fresh menu/command-line launches too, backing up `dolphinrc` before the first
change. Other saved preferences remain user-managed.

Dolphin uses native KDE colors generated from the selected theme roles in
`home/jeffreyc/desktop.nix`, plus the Qt6 KDE platform plugin, Breeze widget style,
and Breeze icons. Package selections override Home Manager's larger KDE defaults
so this does not add System Settings or a Plasma session. Qt environment settings
also affect other Qt clients. `kdeglobals` and the generated color-scheme file
are managed; apart from the startup keys, `dolphinrc`, Places bookmarks, and
per-folder state are preserved.
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

qpdfview is the default for `application/pdf`, replacing the browser association.
`home/jeffreyc/default.nix` supplies a minimal XDG `menus/applications.menu` so
KDE's application index can resolve these associations outside Plasma. Without
that index, Dolphin/KIO can return no PDF handlers despite a correct mimeapps
default. The menu indexes installed desktop entries; it adds no panel or daemon.
The pinned package is built with `qt6Packages` through its existing toolkit
override, sharing Gwenview’s KDE platform plugin, Breeze style, and generated
theme colors. No Qt5 theme adapter or new service is added. It launches on demand;
its normal preferences and document history remain unmanaged.

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
and retains its license; the local C++ adaptation uses the old API and the project's
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
renderer shares textures by prepared path. The renderer bulk-decodes prepared
BMP rows and stages one distinct replacement per render pass, retaining the
old visible assignments until the new set is ready to switch together.
Superseded generated BMPs are removed only after successful loading, under the
helper's nonblocking lock with a fresh
manifest check. Diagnostics serialize on demand rather than during rendering.
These internal optimizations preserve assignments, refresh timing, image quality
and workspace animations.

wlctl is pinned through its upstream flake, following the system nixpkgs input.
Screenshots use an on-demand slurp picker with a slightly bolder shared-theme hover
outline and light dimming outside the selection. Click a visible window for its
rectangle or a gap for that monitor; hold the left button and drag for a free
area. Escape cancels. Grim captures after selection;
the helper saves a PNG under XDG Pictures/Screenshots and copies it with
wl-clipboard. After capture and clipboard success, libnotify sends a three-second
SwayNC confirmation with the saved image as its thumbnail. Cancellation stays
silent. No editor, OCR, or screenshot daemon is added. This replaces Snap's capture UI.
Fn+Prt Sc sends Print on this Lenovo. Bare screenshot hotkeys on Lenovo can
send Meta+Shift+S. Print and Meta+Shift+S launch the same picker. Example
scratchpad bindings are disabled to avoid shortcut conflicts. Only the monitor's
active workspace (or open special workspace), plus visible pinned windows, is offered.
Captures crop visible screen pixels rather than reconstructing obscured windows;
slurp's smallest-rectangle selection can be ambiguous for overlapping floating
windows. The same helper and pinned packages are included in portable bootstrap.
The helper uses Slurp's combined rectangle-click and free-drag mode without `-r`,
retaining `-o` for gap-to-monitor fallback. `packages/slurp/` applies a small
four-logical-pixel threshold before pointer motion replaces a click target with
an area; once dragging starts, it stays an area until release. This avoids tiny
captures from click jitter. The patch builds against pinned Slurp, with headless
checks calling its actual selection handlers for click, overlap, jitter, drag
direction, cross-output coordinates and gesture reset. No new daemon is added.

## Customization decisions

Volume/brightness keys, speaker/mic mute, and Waybar volume scrolling use the
on-demand `desktop-feedback` helper in `home/jeffreyc/packages.nix`. It keeps
wpctl volume controls (5% steps, 100% cap on raising) and brightnessctl’s existing
exponential curve/minimum, then sends the result to SwayOSD’s custom progress
overlay. One Home Manager `swayosd.service` starts with the graphical session;
no input-listening system daemon is enabled. The overlay expires after one second
and never enters notification history. Muted audio retains the percentage and
progress bar; its icon indicates mute. Unmuted icons follow Waybar’s three
volume bands (0–33%, 34–66%, 67% and above). Adwaita’s vector icon assets provide
GTK’s default symbolic icons without adding a theme service. Styling uses the shared theme in
`home/jeffreyc/desktop.nix`. SwayNC stays installed for history and DND; a small
pinned-package UI substitution hides its hardcoded 96px empty-state icon,
leaving a readable, muted “No notifications” label.

- The desktop uses 1.0 scaling, compact gaps, thin window frames, restrained
  corners, and no window shadows. Exact geometry lives in the Hyprland and
  Home Manager desktop configurations.
- Ctrl+Meta+Arrow changes focus directionally through Hyprland's native focus
  dispatcher, repeating when held. Meta+Arrow retains layout movement for tiled
  windows, but moves floating windows by relative pixel increments. Meta+Shift+Arrow resizes by
  relative increments. Both repeat when held; mouse snapping is explicitly
  disabled. Waybar uses matching compact top/side margins and rounded corners,
  preserving its exclusive zone so tiled windows do not overlap it.
  Workspace buttons and system controls use square hover/pressed/active fills
  spanning the bar’s inner height, with zero vertical margins. The outer bar
  retains its existing rounded frame. A 1px margin on the bar’s root content box
  reserves the painted border so button fills cannot cover it. Waybar is visible
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
- Catppuccin Latte remains the default, preserving its existing colors, fonts,
  assets and geometry. `theme/selection.nix` selects Latte or dark Monochrome at
  rebuild time. Shared typography, icons, geometry and material settings live in
  `theme/common.nix`; preset colors and cursor assets live in their own files.
  The wallpaper mode follows the preset (color for Latte, grayscale for Monochrome)
  unless overridden in the selection file. Preparation changes only cached copies
  and keeps color/grayscale cache identities separate. No new service or renderer
  change is required. Adapters consume generic semantic roles, terminal slots and syntax
  purposes rather than Catppuccin palette keys. Shared appearance drives GTK
  preferences/structural variant and Delta; font/icon/cursor package selections
  also live in the plain theme data. Generated Rofi, KDE and Plymouth names are
  stable across themes. Theme changes use normal rebuild activation; no refresh
  coordinator or theme daemon is configured. Meta+Ctrl+T opens the
  existing Rofi as a theme selector; the tray toggle uses Meta+Shift+T. The on-demand
  `scripts/theme-menu.py` helper opens Alacritty for builds and sudo, without a
  new background service or automatic reboot. Available themes come from
  `theme/presets.nix`; active identity comes from the running generation's
  `etc/desktop-theme.json`. The flake passes resolved theme data to both NixOS and
  Home Manager so bootstrapped hosts can retain their selection in
  `/etc/nixos/project-host.json`; bootstrap reruns preserve it. See `theme/README.md`
  for the contract and coverage limits.
- The material direction is matte frosted glass, not liquid/glossy/refractive
  glass. Normal application windows (including LibreWolf and Dolphin) and Rofi
  use Hyprland background blur. Shared opacity and blur controls
  live under `theme/common.nix.material`. Normal windows use a native
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
  opaque. Hyprlock uses a solid, opaque shared theme background, without a
  background screenshot, blur or transparency. Session-lock xray is disabled;
  authentication stays unchanged. Keep the pinned Hyprland version rather than
  upgrading or maintaining a compositor patch for lock-screen effects.
  Waybar and SwayNC are fully opaque, using the shared background role independently
  of the glass opacity and window focus.
  Both Rofi menus share background, text, normal selection colors, typography,
  spacing and focused-window borders. The theme menu marks **Active** in its label
  without requesting a separate active-row color state.
  The notification-center frame uses a
  thin muted outline matching Waybar tooltips; input/control
  outlines, separators and status indicators remain useful and are not removed.
  No shader, refraction plugin, highlight gradient, shadow or new service is added.
- Fonts share the family and point size in `theme/common.nix` across terminal,
  launcher, bar, notifications, GTK defaults and KDE UI roles. CSS uses `pt`, not
  `px`, to avoid unit mismatches. Web content and app-specific overrides are not
  forced. Display scaling remains unchanged.
- Latte uses packaged Catppuccin Mocha Dark cursor assets for contrast. Monochrome
  uses DMZ White from the small `vanilla-dmz` cursor package. Its package/name/size come from the shared theme for both
  Home Manager and SDDM. Home Manager configures Hyprcursor, Xcursor, GTK and KDE;
  this is an asset exception, not a second application palette or theme switcher.
- Generic GTK3 styling uses pinned `adw-gtk3` as widget structure, with generated
  semantic colors from the shared theme. GTK4/libadwaita uses named colors and
  modern CSS variables without replacing its native layout. Light/dark appearance
  follows the selected preset through Home Manager's GTK/dconf integration.
  Legacy GTK2 colors and apps isolated from or overriding the host stylesheet
  are not claimed covered.
- SDDM uses pinned `where-is-my-sddm-theme` as a minimal layout, configured from
  shared colors, typography and cursor settings. Small fail-fast substitutions
  cover its otherwise hardcoded selection/error colors and pulsing error border.
  The theme's QML dependencies are passed through SDDM's `extraPackages`; no
  display-manager replacement or new session service is introduced. Activation
  leaves the running display manager alone; the new configuration takes effect
  when SDDM next starts, normally on the next boot.
- Hyprlock has a generated minimal theme config and a normal NixOS PAM entry.
  Configure PAM directly rather than enabling the NixOS hyprlock module, which
  implicitly enables hypridle in this pinned release. No idle daemon, auto-lock
  timer, grace period or authentication bypass is configured. Parser checks and
  login-screen test mode do not establish successful real authentication.
- Native theme adapters consume the shared definitions for Hyprland borders,
  Alacritty, Rofi, Waybar, SwayNC, and Dolphin/KDE Qt colors. Keep app-specific syntax in the existing
  modules; do not install independent Catppuccin palettes. Canonical palette
  values stay opaque; shell backplates and normal windows add alpha at the adapter
  boundary. Their displayed tint now intentionally depends on the blurred content
  behind them. See `theme/README.md` for
  researched integration details and the remaining unthemed components.
- Validation runs locally; no GitHub Actions workflow is configured. Repository
  visibility and remote settings are managed separately from the system configuration.

## Repository map

- `flake.nix` and `flake.lock`: inputs, host output, Home Manager integration,
  formatter.
- `hosts/nixos/`: machine identity, account, disk UUIDs, encryption, boot hardware.
- `modules/nixos/`: core OS, AMD/laptop support, and system desktop integration.
- `home/jeffreyc/`: user identity/session variables, packages, programs, desktop.
- `dotfiles/hypr/`: managed Hyprland Lua configuration.
- `theme/`: selected theme data and theme-agnostic adapter contract.
- `tests/`: bootstrap, portable-host, power, charging, screenshot and wallpaper checks.
- `packages/`: local package overrides, compositor adaptation and utility patches.
- `README.md`: project overview, quick start and documentation index.
- `AGENTS.md`: instructions for how agents should work.
- `docs/wallpapers.md`: wallpaper implementation, cache, and troubleshooting.

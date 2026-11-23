# System context and decisions

I keep my system design, configuration decisions, and validation limits here.
The Nix configuration is authoritative for exact values. This document does not
establish what is currently activated or running; inspect the host when needed.
Git history records changes. The bootstrap observations in `audit.md` are
historical.

I checked my host against the checkout on 2026-10-29: both selected and running
kernels were 7.2.10, the active desktop theme was Latte, and no system or user
services were failed. The live compositor service had `OOMPolicy=continue` in
`session.slice`; `app.slice` had memory-pressure and swap killing enabled. Zswap
was enabled with zstd and a 20% pool limit. Declared Nix build limits were two
concurrent builds and two cores per build. These observations are a dated
verification, not a guarantee about later sessions.

## Machine and configuration

My host is `nixos`, an `x86_64-linux` Lenovo IdeaPad 5 2-in-1 14AKP10, with
primary account `jeffreyc`. My hardware includes a Ryzen AI 7 350, Radeon 860M,
AMD XDNA NPU, MediaTek MT7925 Wi-Fi, roughly 13 GiB usable RAM, and a 476.9 GiB
NVMe SSD. Touchscreen, Wacom pen/touch, and tablet mode matter when evaluating
hardware or desktop changes.

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

ADB is installed system-wide through `android-tools` in `modules/nixos/core.nix`,
including on bootstrap-generated hosts. The pinned NixOS release uses systemd's
USB uaccess rules, so no `adbusers` group or extra udev package is needed.
The ADB server starts on demand when a command needs it; no autostart service is
configured. Run `adb devices` after enabling USB debugging on the Android device
and approve the computer on the device when prompted.

Cisco Packet Tracer is supplied by pinned nixpkgs, launched as `packettracer9` or
through its desktop entry. The package selects XWayland locally. Cisco's matching
installer is a separately downloaded input. Bootstrap verifies and imports it
from `~/Downloads` when absent from the store, or skips Packet Tracer when no
matching installer is available. Generated hosts record `packetTracerEnable`
for later rebuilds; my Lenovo target keeps it enabled. See the
[desktop guide](desktop.md#cisco-packet-tracer) for the exact version and manual
import command; binaries, license state and Cisco credentials stay outside the
repository.

Joplin Desktop is declared in `home/jeffreyc/packages.nix` from the pinned unstable
input for a version newer than 3.7.0; stable nixpkgs supplies 3.5.13.
It launches with Meta+J, from the app menu or `joplin-desktop`; no autostart service or sync
account is configured. Notes and application preferences remain user-managed.

Vesktop provides Discord through Home Manager in `home/jeffreyc/programs.nix`,
using the source-pinned Vencord override in `packages/vencord.nix` with NoTrack
enabled and local CSS filters for Store, Nitro and sponsored Quest promotion.
It starts on demand, quits when closed, and disables Rich Presence and Vencord
cloud sync. Client modifications violate Discord's terms; cosmetic filters do not guarantee that
future Discord interfaces remain free of ads. See the [desktop guide](desktop.md#discord-with-vesktop)
for configuration ownership, update behavior and limits.
Its existing Quick CSS also translates the selected theme's interface roles and
font family into Discord's current and legacy color tokens. It applies across
Discord's account themes; media and server artwork retain their own colors.
Read channel labels use secondary text, while selected channels use the shared
selection pair. Current composer background and placeholder tokens are mapped
explicitly so Discord's account palette cannot leave a light input in a dark theme.

The Vencord override addresses a Discord web-client compatibility failure:
on 2026-11-12 the stable input's 1.15.10 produced a blank page with
`TypeError: i.A is not a constructor`, including with a fresh profile under Xvfb.
The updated revision rendered the login screen with the same Vesktop version
and privacy settings. Signed-in chat and calls were not covered by that test.

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

Moonlight Qt is declared in `home/jeffreyc/packages.nix` from pinned stable
nixpkgs with the local theme adapter in `packages/moonlight-theme.nix`.
Moonlight forces Qt Quick Material instead of using the KDE widget palette;
the adapter supplies the shared colors, font and appearance, replaces hardcoded
backgrounds and section-heading colors, and recolors white interface icons for
light themes.
Its QML disk cache is scoped to the executable's store path, preventing stale
cached colors after a rebuild without deleting existing caches or preferences.
Native control layouts, artwork and streamed video stay unchanged.
Launch **Moonlight** from Rofi or run `moonlight`; it starts on demand
without a new background service. Paired hosts and streaming preferences remain
user-managed.

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

`~/Waydroid` provides writable access to Android's shared media storage,
including Pictures and DCIM, through an on-access bindfs mount. A root
preparation oneshot creates missing directories; bindfs maps desktop access and
preserves Android media ownership for new files. Home Manager adds **Waydroid**
to Dolphin Places through a preserving XBEL helper, backing up the original
first. Existing bookmarks and Dolphin state remain user-managed. An event-driven
systemd path unit watches direct changes to Pictures, DCIM and Download and runs
an Android media-index scan only while the container is running. This handles
host writes that bypass Android's emulated-storage notifications; existing
nested directories require a manual scan. Images and the Aurora APK are pinned
in `packages/waydroid/default.nix`; no APKs, Android images or account data are
committed to Git. See [Waydroid](waydroid.md) for setup, stopping Android,
updates and runtime validation limits. The vendor image includes a small YV12
layout adapter for Instagram's native graphics crash, preserving GPU
acceleration. It corrects video-plane metadata around the pinned minigbm
backend. The repair lives in the immutable vendor image so switching generations
can remove it; Android user data stays separate. The Android controller restarts
when its image derivation changes. Stop Android before image updates. Native
buffer tests and Instagram startup were verified on 2026-10-29. I also checked
normal video/Reels playback, but I have not completed the full photo-upload
check.

I use a separately signed Instagram clone with Home/Reels navigation and thread-header
Blend controls removed. Direct is the default tab; the original app stays disabled
and hidden for recovery. I keep normal desktop tiling and Android's saved light
appearance. I was satisfied with the Home/Reels behavior on 2026-11-01; narrow UI
changes should preserve that baseline.

I keep the manual build/update workflow, signing-key requirements, exact input
pins, and verification limits in the [Instagram package guide](../packages/instagram-reels/README.md).
The [Waydroid guide](waydroid.md) covers launchers, photo access, volume, and
per-window scrolling. Private keys, original APKs, and account data stay outside
Git and the Nix store. The clone is updated manually, independently of normal
Play/Aurora updates; it does not block every alternate route into feed content.

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

My local review on 2026-10-31 covered effective NixOS settings, live IPv4/IPv6
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
Forwarding used the then-enabled Tailscale/Waydroid integration; this input-rule
review does not establish isolation between every routed network.

I use manual locking and have not added an automatic idle lock. Independent
personal-data backups and a restore trial remain a separate recovery
requirement. I did not include external penetration testing or a complete
dependency vulnerability audit in that review, and I did not establish
successful physical lock/unlock.

My host trusts the homelab Caddy root CA through `security.pki.certificateFiles`
in `hosts/nixos/default.nix`. Its public certificate is stored in
`hosts/nixos/certificates/hermes-root-ca.crt`; no private key belongs in the
repository or Nix store. This host-specific trust is not inherited by portable
bootstrap installations. Replacement certificates require fingerprint
verification before changing the trust anchor. The pinned LibreWolf NSS library
uses p11-kit for its root store, so this CA does not require a separate browser
import policy. On 2026-11-01, a fresh LibreWolf 158 profile reported the CA
trusted for TLS and opened the homelab login page with certificate verification
enabled and no saved exceptions. An already running browser may need a normal
restart to refresh its trust store.

My laptop uses NetworkManager's native WireGuard profile for Hermes, with
automatic activation away from its saved home NetworkManager connection and
deactivation at home or without an uplink. The existing NetworkManager
dispatcher runs the policy; no new daemon or timer is installed. Credentials are
imported at runtime into a root-only keyfile outside Git and the Nix store. The
host enables systemd-resolved for per-domain DNS routing; NetworkManager reloads
configuration changes without reconnecting Wi-Fi. The VPN sends `home.arpa`
queries to Hermes only while active. See [homelab VPN](homelab-vpn.md) for
import, toggling, verification, manual pause and recovery. The existing Caddy
trust declaration is independent.

My saved `Hermes-Trusted` Wi-Fi profile is pinned to the home 5 GHz access point
to disable background roaming scans during remote play. The host-only
`hermes-wifi-pin` oneshot service applies the BSSID in `hosts/nixos/default.nix`
after NetworkManager starts and when its service definition changes. It updates
the existing profile without copying credentials into Nix or reconnecting an
active link; a changed pin takes effect on the next connection. Roaming to other
radios or mesh nodes is disabled for this profile. If I replace the access point,
I update the pin; to restore roaming, I remove the service and clear the profile's
`802-11-wireless.bssid` with `nmcli connection modify Hermes-Trusted
802-11-wireless.bssid ""`, then reconnect. Other saved networks and portable
bootstrap hosts keep their normal roaming behavior.

## Desktop components

My desk has an upside-down Acer KG251Q centered above the P2510S, with the
laptop on the lower display's left. `hosts/nixos/monitors.lua` matches EDID
descriptions; it is not used by portable bootstrap hosts. Both external screens
use 120 Hz (119.98 Hz on the Acer), with the laptop at its preferred mode, all
at 1.0 scaling. A short simultaneous dual-120 Hz hardware trial succeeded, but I
still noticed latency on the upper display; refresh rate alone does not explain
that symptom. The reference dock identifies as a ThinkPad Universal USB-C Smart
Dock (40B2). The local `packages/hyprland-full-edges/` plugin supplies
proportional cursor crossing along entire shared edges. It hooks relative
pointer motion against the pinned compositor ABI, without a service or
input-device access; constraints, locking and absolute input bypass it.

Ten logical desktops span connected outputs through native Lua coordination in
`dotfiles/hypr/workspace-groups.lua`. Each screen retains its own native workspace
and tiling layout, with Waybar showing the logical desktop number. Native
workspace events synchronize keyboard, Waybar and completed swipe navigation.
Undocked windows merge into their matching desktop on surviving screens and
remain there after redocking. Disconnected outputs' persistent workspace rules
are retired until they return. Waybar-driven switches synchronize in the next
event-loop turn after the native click dispatcher completes, avoiding nested
workspace transitions. See [desktop controls](desktop.md#monitors-and-shared-desktops)
for IDs, startup behavior and swipe limitations. No workspace-manager daemon or
additional workspace plugin is installed.

My host prefers the RØDE AI-1 for playback and capture when attached. Its Home
Manager configuration in `hosts/nixos/default.nix` installs a user WirePlumber
ALSA priority fragment. WirePlumber reads it when its session next starts;
routine activation does not restart the audio session. `wpctl set-default`
selects both live endpoints and stores my current choice, while current
PulseAudio-compatible streams can be moved with `pactl`. Unplugging the
interface retains normal fallback selection. Portable hosts do not inherit this
desk rule. The saved default is matched only against available audio nodes; the
pinned WirePlumber selection hooks are exercised by
`tests/test_audio_fallback.lua` for repeated USB removal/return with laptop
speakers and microphone available. Internal audio remains enabled, and the
running stream policy allows fallback and reconnection. This does not establish
a physical dock-removal test.

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

My existing systemd-oomd monitors my user manager's `app.slice` for sustained
memory pressure and nearly exhausted swap. It can terminate an entire
application unit, including unsaved work, to release memory before prolonged
system stalls. Hyprland and core session services in `session.slice` are outside
this monitoring scope. This is declared in `modules/nixos/core.nix` and starts
through systemd; no second OOM daemon or arbitrary per-app RAM cap is installed.
Pressure thresholds measure time stalled on memory, not the percentage of RAM
occupied. This policy does not guarantee recovery from every allocation burst or
kernel OOM.

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
| Fonts | Monaspace Neon, Nerd Font symbols, Noto, Noto Emoji, Microsoft core fonts | NixOS desktop module and application settings |
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

The same Waybar package backports upstream's family-specific address-removal
handling. Stock 0.15.0 clears its cached IPv4 address when an IPv6 address expires,
which can leave a working Wi-Fi connection displayed as linked without an IP.
`packages/waybar-tray/network-address-family.patch` preserves the other address
family; network configuration and the existing session service remain unchanged.

Wiremix comes from the public `AldogPlays/wiremix` fork on
`codex/ui-match`, pinned in `flake.lock` and following the system nixpkgs.
`home/jeffreyc/packages.nix` selects the fork instead of stock Wiremix, retaining
the `wiremix` command and desktop entry for both existing floating launchers.
The fork's single-page audio sections and contextual controls replace its UI;
PipeWire/WirePlumber and their startup remain unchanged. No local checkout path,
imperative installation, or extra service is required on a new machine.

The four floating controls share launch policy in `home/jeffreyc/desktop.nix`.
It generates the keyboard and Waybar commands from the same executable paths,
terminal options and app IDs, and supplies the matching floating-rule classes.
The theme-switching terminal stays separate because of its rebuild and
password-prompt lifetime.

The TUI controls, including btop's CPU/memory/process/battery monitor, are launched on demand; the
network/Bluetooth/audio backend services remain enabled. Their dedicated
Alacritty app IDs float through `dotfiles/hypr/hyprland.lua`. Keyboard and Waybar
launch commands bind unmodified Escape to Alacritty's Quit action for these
windows only, closing even an active TUI prompt. No extra service is involved.
nm-applet, Blueman, and pavucontrol are no longer declared as front ends.
The monitor uses the same UWSM launch and Escape-to-close behavior, with no new
background service. Its dedicated Alacritty class is `system-monitor`.

Tailscale is not included in the shared configuration. Homelab VPN access uses
my host's NetworkManager WireGuard profile described above.

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
discarded. Gwenview supplies image viewing and quick editing. I haven't chosen
dedicated media-player, mail, or general GUI editor defaults; I keep those roles
open rather than installing a bundle.

The application menu uses declarative desktop-entry overrides in
`home/jeffreyc/packages.nix` for short descriptions and hidden utility entries.
Upstream MIME associations, actions and launch arguments are preserved. Rofi's
own overrides are also linked into my user application directory, ahead of the
original entries that its wrapper prepends to `XDG_DATA_DIRS`. The writable
Android/game exports are updated by the existing activation helper; Waydroid
preserves its custom visibility and description fields on refresh. **Theme
Selector** launches the existing `theme-menu` command, shared with Meta+Ctrl+T,
to choose and apply the system theme. The upstream Rofi-only picker is replaced
in the application menu. No launcher service is added.

Meta+E explicitly passes the account's home directory to a new Dolphin window.
A preserving Home Manager activation sets Home and disables tab restoration for
fresh menu/command-line launches too, backing up `dolphinrc` before the first
change. Other saved preferences remain user-managed.

Dolphin uses native KDE colors generated from the selected theme roles in
`home/jeffreyc/desktop.nix`, plus the Qt6 KDE platform plugin, Breeze widget
style, and Breeze icons. Package selections override Home Manager's larger KDE
defaults so this does not add System Settings or a Plasma session. Qt
environment settings also affect other Qt clients. `kdeglobals` and the
generated color-scheme file are managed; apart from the startup keys,
`dolphinrc`, Places bookmarks, and per-folder state are preserved. KDE's
terminal settings point to Alacritty for external terminal launches. The
embedded Konsole panel and extra indexer are not installed. KIO/KIO extras and
icon assets already occur in Dolphin's dependency closure. KIO extras is also
exposed in my user profile so its MTP D-Bus service and kiod plugin can be
discovered outside Dolphin's wrapper. The shared desktop module registers
libmtp's udev rules and hardware database so Dolphin can identify USB phones in
file-transfer mode. The existing udev service handles detection; KIO accesses
the phone on demand.

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

ONLYOFFICE Desktop Editors replaces AbiWord for Microsoft Office compatibility.
`home/jeffreyc/packages.nix` declares the pinned stable package and descriptive
launcher entry; `home/jeffreyc/default.nix` sets DOCX, DOC, ODT and RTF defaults.
The single package includes document, spreadsheet and presentation editors and
uses DOCX, XLSX and PPTX natively. It runs on demand through the app launcher,
Dolphin or `onlyoffice-desktopeditors`, with no new service or cloud account.
The pinned nixpkgs wrapper supplies its FHS runtime and selects XWayland for the
bundled Qt version. Its built-in interface is outside shared-theme coverage;
document contents and writable preferences remain user-managed. The shared NixOS
desktop module installs Microsoft's `corefonts`, including Times New Roman's
four styles, for document compatibility. Fontconfig exposes them system-wide;
ONLYOFFICE picks them up when reopened, without an additional service.
The local package override passes `--xdg-desktop-portal=default` on every launch,
using the existing GTK file portal for open/save dialogs outside the editor
process. This avoids the unreadable text observed in its in-process GTK picker,
without adding a backend or changing the global font. Reopen ONLYOFFICE after
activation to use this path.
The wrapper also includes the shared UI font in its FHS font tree. Native GTK
warnings resolve that font under `/usr/share/fonts`; without it, Pango reports
the font file missing and draws boxes for the message and buttons.
Native OOXML support does not guarantee exact Word layout or feature parity;
see the [desktop guide](desktop.md) for usage and compatibility references.

Ark is the archive viewer and supplies Dolphin's native extraction/compression
service menus. Archive MIME defaults are derived from its desktop entry rather
than maintained as a separate MIME list. Its native libzip/libarchive plugins
handle common ZIP/tar formats; the maintained upstream 7-Zip package backs the
7z plugin. Pinned Ark 26.04.3 invokes `7z`, while nixpkgs `_7zz` installs `7zz`,
so `home/jeffreyc/packages.nix` adds a compatibility symlink to that same binary.
Do not replace it with an obsolete p7zip package or install an entire KDE bundle.
Ark follows the shared Qt/KDE theme and starts on demand, without a new daemon.

I use hyprmosaic as the sole wallpaper renderer. Its wallpaper-only backport
tracks native workspace motion; interrupted slides preserve their visible image
positions without changing window animations. Native Lua events start a short-lived
preparation helper; ordinary workspace switches do not launch a wallpaper process.
I keep image originals, assignments, and caches outside Git and the Nix store.
My [wallpaper guide](wallpapers.md) covers the rendering model, cache/memory limits,
regression checks, diagnostics, and recovery.

I use the on-demand Slurp/Grim screenshot helper for both Print and Meta+Shift+S.
It supports window/monitor clicks and free-area dragging, saves under XDG
Pictures/Screenshots, copies the image to the clipboard, and sends a brief
notification after success. I keep usage and capture limitations in the
[desktop guide](desktop.md#wallpapers-and-screenshots) and the click-tolerance
patch contract in the [Slurp guide](../packages/slurp/README.md). No screenshot
daemon, editor, or OCR service is configured.

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
  reserves the painted border. Both themes curve the outer workspace and
  notification fills inside that frame; interior fills remain square. Each Waybar is
  visible only when its own monitor has a mapped, non-hidden window on a visible
  workspace, including floating/PiP and pinned windows. A manual tray pin reveals
  the focused monitor's bar; Rofi alone does not reveal an empty screen's bar.
  `dotfiles/hypr/waybar-policy.lua` owns tray pinning, visibility and scheduling;
  the compositor loads it once and binds its `toggleTray` action.
  Native Lua window/workspace/layer events write an atomic per-output runtime
  manifest and signal `waybar.service` with SIGRTMIN+10. The existing local Waybar
  package applies explicit output states without globally toggling other bars.
  Invisible Waybar stays
  mapped, so the explicit invisible mode uses the bottom layer while the visible
  bar uses top; Lua queries this real state, without a stale visibility cache.
  Small one-shot timers coalesce events and asynchronous signals. No polling loop
  or extra service is added. The existing Home Manager reload signal is preserved.
  Hidden Waybar releases its exclusive zone; visible Waybar reserves
  space as before. Workspace labels show occupied logical desktop groups plus
  the current desktop; the `.visible` state highlights each screen's displayed
  desktop independently of focus. Native persistent workspaces remain available
  for navigation while unused buttons are hidden.
- I keep the touchpad usable during typing and use non-natural scrolling.
  Both `disable_while_typing` and `natural_scroll` are false in the Lua source.
  The Ninjutso Sora 4K alone has a slower device-specific sensitivity override;
  ELAN touchpad/mouse settings remain at the shared defaults. The mouse override
  is independent of docking and follows the matching device when connected.
- Windows explicitly marked modal float through a single Hyprland rule. Normal
  application windows stay tiled. Modal detection does not use broad title
  heuristics or Bitwarden-specific exceptions; the separate browser PiP rule
  below uses its known dedicated title. Unmarked extension windows may need
  separate inspection if this baseline does not catch them.
- I use Monochrome and keep Catppuccin Latte available. I keep shared colors,
  typography, geometry, cursor assets, and material settings in `theme/`.
  Application modules consume semantic roles rather than independent palettes.
  My [theme guide](../theme/README.md) is the reference for adapters, exceptions,
  coverage limits, and activation behavior.
- I change themes through the normal rebuild workflow. The on-demand Rofi menu
  stores the selection in the checkout or generated host; it adds no resident
  theme service. Wallpaper color can be chosen independently, and preparation
  changes only cached copies of my originals.
- I use matte frosted glass for normal windows and Rofi, without glossy or
  refractive effects. Focused/fullscreen windows remain opaque; unfocused normal
  windows use the declared opacity. Native terminal alpha stays opaque to avoid
  multiplying transparency. Waybar, SwayNC, the greeter, and the lock screen stay
  opaque. I keep thin borders, compact spacing, and no window shadows.
- I keep explicitly modal windows and recognized Firefox-family PiP opaque.
  PiP matching uses the known class and exact English title, with initial sizing
  applied once so manual resizing remains available. I do not treat every
  floating window or extension window as a modal dialog.
- I share font family and point size across the native adapters; CSS uses `pt`.
  Media, server artwork, web content, and application-specific overrides retain
  their own colors or typography where documented. Cursor packages are an
  explicit asset exception, chosen for contrast rather than as extra app themes.
- I retain the minimal SDDM layout and its local Monochrome substitutions for
  selection/error colors and monitor-local positioning. Activation leaves the
  running greeter alone. I verify those substitutions against the pinned package
  when upgrading; a theme change does not justify replacing the login manager.
- I configure hyprlock's PAM service directly: enabling the pinned NixOS hyprlock
  module would also enable hypridle. I use manual locking, with no automatic idle
  lock, grace period, or authentication bypass. The lock screen has a solid
  background, without a screenshot or transparency. I retain the pinned
  compositor rather than adding a lock-screen-effects patch.

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

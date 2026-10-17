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

The stable OS input is `nixos-26.05`. Home Manager follows it through
`release-26.05`; `flake.lock` pins revisions. A separate unstable input supplies
Codex so that tool can advance independently of the OS base. Home Manager is
integrated into the NixOS rebuild, rather than maintained as a separate switch.
Both compatibility baselines are `26.05`.

The official ChatGPT desktop app provides graphical Codex alongside the Codex CLI.
Both are declared from the pinned unstable input; the Linux desktop launcher is
`chatgpt`. This uses nixpkgs' adaptation of the official application binary.

The kernel selection is `pkgs.linuxPackages_latest` from the stable input. Recent
hardware support is a consideration when reviewing that choice, but a specific
requirement for this kernel has not been established.

Root is LUKS-encrypted Btrfs, mounted at the top level. `/home` and `/nix` are
separate subvolumes sharing its capacity. `/boot` is a separate EFI partition;
swap is a separate encrypted 8.8 GiB partition. There is no declared resume device,
snapshot policy, or Btrfs compression setting. Recovery tooling requires a design
appropriate to this layout. Weekly Nix garbage collection retains according to
`--delete-older-than 30d`; it is not a personal-data backup.

Home Manager's conflicting-file backup suffix is `.hm-backup`. The current editor
is Nano, shell is Bash, locale is `en_US.UTF-8`, and timezone is
`America/Los_Angeles`.

## Desktop components

These are declared choices, subject to Jeffrey's review rather than a commitment
to keep every bootstrap component.

| Role | Component | Configuration |
| --- | --- | --- |
| Compositor and session | Hyprland, UWSM, XWayland | `modules/nixos/hyprland.nix`; `dotfiles/hypr/hyprland.lua` |
| Login greeter | SDDM with Wayland enabled | `modules/nixos/hyprland.nix` |
| Bar and notifications | Waybar, SwayNotificationCenter | `home/jeffreyc/desktop.nix`; Super+N toggles the notification center |
| Launcher | Rofi (native Wayland), Super+R | `home/jeffreyc/programs.nix`; Hyprland bindings |
| Lock screen | hyprlock, Super+L | Package and binding only; no custom theme or idle-lock service |
| Terminal and files | Alacritty, Super+Q; Dolphin, Super+E | Home Manager programs/packages; Hyprland bindings |
| Browser | LibreWolf | Home Manager packages and session variables |
| Network controls | NetworkManager, wlctl | Click Waybar network or Super+Shift+N to open wlctl in Alacritty |
| Bluetooth controls | BlueZ, Bluetui | Click Waybar Bluetooth or Super+Shift+B to open Bluetui in Alacritty |
| Authentication prompts | polkit, hyprpolkitagent | NixOS desktop module and Home Manager session service |
| Audio | PipeWire, WirePlumber; Wiremix, wpctl | Click Waybar volume or Super+Shift+A for Wiremix; media keys retain wpctl |
| Portals | Hyprland and GTK backends | Hyprland's NixOS module supplies its portal; GTK is added explicitly |
| Screenshots and clipboard | yumedots/snap, wl-clipboard | Print opens Snap; `packages/snap.nix`; no clipboard-history manager |
| Brightness and media | brightnessctl, playerctl | User packages and Hyprland bindings |
| Fonts | Monaspace Neon, Nerd Font symbols, Noto, Noto Emoji | NixOS desktop module and application settings |
| Wallpaper | wpaperd | Home Manager session service; packaged NixOS dark-gray placeholder |
| Workspace overview | Hyprspace | Same pinned nixpkgs/Hyprland build; rendered Lua plugin path; Super+Tab |

Firmware updates, power profiles, and battery state are supported by fwupd,
power-profiles-daemon, and UPower. The TUI controls are launched on demand; the
network/Bluetooth/audio backend services remain enabled. nm-applet, Blueman,
and pavucontrol are no longer declared as front ends.

wlctl is pinned through its upstream flake, following the system nixpkgs input.
Snap's source is locked as a non-flake input and built locally with xmake, with
Nix paths substituted for upstream's distribution-specific protocol paths. Its
wrapper provides clipboard, OCR, and Hyprland commands without requiring Omarchy.
Hyprspace uses `pkgs.hyprlandPlugins.hyprspace` with a source override pinned in
`flake.lock` to upstream's Hyprland 0.55.4 compatibility revision. This supplies
the required Lua bindings while building against the same Hyprland/compiler
pairing as the compositor. Review that compatibility pin during Hyprland upgrades.

## Customization decisions

- The requested look uses 1.5 scaling, compact gaps, thin borders, restrained
  corners, and no window shadows. Exact geometry lives in the Hyprland and
  Home Manager desktop configurations.
- The touchpad should remain usable during typing and use non-natural scrolling.
  Both `disable_while_typing` and `natural_scroll` are false in the Lua source.
- The theme direction is fixed Catppuccin Latte, with locally versioned official
  palette values and shared semantic roles. No switching, refresh coordinator,
  or theme daemon is wanted. See `theme/README.md` for the data contract.
- Theme groundwork is intentionally disconnected from applications. The desktop
  component migration is requested separately from color integration. Future
  adapters should consume the shared theme definitions when that work is requested.
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
- `theme/`: shared Latte data and future adapter contract.
- `packages/`: local packages for requested tools missing from the pinned nixpkgs.
- `README.md`: setup, rebuild, and maintenance commands.
- `AGENTS.md`: instructions for how agents should work.

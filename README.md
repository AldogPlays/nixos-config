# NixOS + Hyprland

A personal NixOS desktop built around Hyprland, Home Manager and pinned flake
inputs. Compact spacing, thin borders and a shared theme keep
the desktop consistent without installing a full desktop environment.

The checked-in `nixos` host targets a Lenovo IdeaPad 5 2-in-1 14AKP10. A separate
bootstrap command adopts an existing **x86-64 NixOS installation**, preserving
its own account, disks, encryption, bootloader and graphics settings.

## What is included

- Hyprland with UWSM, Waybar, Rofi, notifications, lock screen and a graphical login.
- Shared theme roles for desktop components, GTK/Qt applications, terminal colors,
  typography and cursor assets. Theme-specific palette names stay inside `theme/`.
- Workspace-linked wallpapers, window/area screenshots and clipboard integration.
- Dolphin, darktable, image/PDF/archive tools, LibreWolf, Joplin and gaming applications.
- On-demand Waydroid with Aurora Store and a Dolphin photo-upload folder.
- Terminal-based Wi-Fi, Bluetooth and audio controls.
- Automatic power profiles, low-battery brightness handling and firmware battery
  conservation on supported hardware.
- Memory-pressure safeguards, compressed swap caching on hosts with disk swap,
  and Nix build limits that leave room for desktop applications.
- Portable bootstrap with a preview, a full build before activation and a backup
  of the existing `/etc/nixos` configuration.

## Get started

Start from an installed NixOS 26.05 system, signed in as the existing desktop
account. This is a desktop configuration and adoption tool, not a disk installer.

**Read the [installation guide](docs/installation.md) first.** The package set
includes proprietary applications; Cisco Packet Tracer requires its matching
installer to be downloaded separately. Preview before applying the configuration.

Once the repository is publicly accessible, preview with:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:AldogPlays/nixos-config#bootstrap
```

For an authenticated checkout, use `nix run .#bootstrap` from its root instead.
The [installation guide](docs/installation.md#repository-access) covers restricted
repository access and the activation command.

**Do not apply `.#nixos` on another computer.** That target contains this Lenovo's
account and disk identifiers. Use bootstrap to generate an installation-specific
host instead.

## Documentation

| Guide | Contents |
| --- | --- |
| [Installation](docs/installation.md) | Requirements, preview, activation, supported layouts and limits |
| [Desktop](docs/desktop.md) | Shortcuts, applications, charging controls and daily use |
| [Waydroid](docs/waydroid.md) | Android, Aurora Store and photo uploads |
| [Maintenance and recovery](docs/maintenance.md) | Validation, rebuilds, updates and rollback |
| [Theme contract](theme/README.md) | Shared roles, native adapters and current coverage |
| [Workspace wallpapers](docs/wallpapers.md) | Rendering, image preparation, cache and diagnostics |
| [System context](docs/system-context.md) | Reference-host architecture and configuration decisions |
| [Bootstrap audit](docs/audit.md) | Historical observations from the initial migration |
| [Contributing](CONTRIBUTING.md) | Bug reports, changes and local checks |
| [Agent guide](AGENTS.md) | Repository workflow and rules for coding assistants |
| [Security](SECURITY.md) | Sensitive reports and information to omit from public logs |
| [Publishing](docs/public-release.md) | Final checks and the separate visibility change |

## Everyday controls

Meta/Super is the Windows or logo key.

| Action | Shortcut |
| --- | --- |
| Terminal / browser / files | Meta+T / Meta+F / Meta+E |
| App launcher | Meta+A |
| Theme selector | Meta+Ctrl+T |
| Workspaces 1–10 | Meta+1–9, Meta+0 |
| Notifications | Meta+N |
| Wi-Fi / Bluetooth / audio | Meta+Shift+N / B / A |
| Screenshot | Print or Meta+Shift+S |
| Lock screen | Meta+L |

The [desktop guide](docs/desktop.md) lists the complete controls and behavior.
The [maintenance guide](docs/maintenance.md#desktop-memory-safeguards) covers live
memory checks and garbage collection that preserves existing rollback generations.

## Theme choice

Press **Meta+Ctrl+T** for the Rofi theme menu. It marks the active theme; choosing
another opens a terminal to build and apply the configuration with normal sudo
authentication. Escape cancels. No automatic reboot is performed.

Latte is the default. Monochrome uses a dark grayscale desktop and
grayscale wallpaper copies, preserving the original images. Wallpaper color
can also be chosen independently. See [theme selection](theme/README.md#choose-a-theme)
for settings, manual selection and activation details. The rebuild includes other
saved configuration edits.

## Repository layout

```text
flake.nix, flake.lock    pinned inputs, systems, bootstrap and checks
hosts/nixos/            reference Lenovo host and its hardware configuration
modules/nixos/          shared OS, hardware and desktop modules
home/jeffreyc/           shared Home Manager configuration
bootstrap/, scripts/    installation templates and system helpers
dotfiles/               compositor, wallpaper and boot-screen sources
theme/                  selected theme data and adapter contract
packages/               local packages and patches
tests/                  regression checks
docs/                   setup, daily use and implementation details
```

The `home/jeffreyc/` directory is reused by bootstrap with the destination account's
login and home directory; its directory name does not create that account.

## Compatibility and validation

The reference Lenovo is used daily. Local checks also evaluate complete
Intel/UEFI, AMD/BIOS and NVIDIA configurations and exercise bootstrap, charging,
power, screenshot selection and wallpaper policies. Those checks do not establish
successful installation, boot or graphics behavior on every supported PC.
The bootstrap activation path still needs a fresh VM or spare-PC trial.

Boot-screen authentication and the physical battery charging cutoff also require
hardware observation. See the component guides for the specific validation limits.

## License

Original source and documentation are available under the [MIT license](LICENSE).
Adapted code, palette data and packaged applications retain their respective
licenses; see [third-party notices](THIRD_PARTY_NOTICES.md).

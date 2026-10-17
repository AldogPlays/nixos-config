# NixOS configuration

Flake-based NixOS and Home Manager configuration for the `nixos` host (Lenovo IdeaPad 5 2-in-1 14AKP10) and user `jeffreyc`.

## Layout

```text
AGENTS.md                     working directions for agents
flake.nix                     pinned inputs and host output
hosts/nixos/                  machine identity, disks, and boot hardware
modules/nixos/                reusable OS, hardware, and desktop modules
home/jeffreyc/                Home Manager modules
packages/                     local Nix packages (Snap)
dotfiles/hypr/                versioned Hyprland configuration
theme/                        shared Latte palette, semantic roles, adapter contract
docs/system-context.md        system inventory and configuration decisions
docs/audit.md                 bootstrap hardware/configuration audit
```

The fixed Catppuccin Latte theme is documented in
[theme/README.md](theme/README.md). Hyprland borders, Alacritty, Rofi, Waybar,
SwayNC, and Dolphin/KDE Qt colors consume the shared palette. Other applications
remain separate follow-up work.

## Desktop controls

| Action | Shortcut or control |
| --- | --- |
| Terminal (Alacritty) | Meta+T |
| New LibreWolf window | Meta+F |
| Close focused window | Meta+Q |
| Toggle floating | Meta+W |
| Toggle fullscreen | Alt+Enter |
| Workspace 1–10 | Meta+1–9, Meta+0 for 10 |
| Move window to workspace | Meta+Shift+1–9 or 0 |
| Move focused window in layout | Meta+Arrow |
| Resize focused window | Meta+Shift+Arrow; 20 px steps, hold to repeat |
| File browser (Dolphin) | Meta+E |
| App launcher (Rofi) | Meta+A |
| Notification center (SwayNC) | Super+N or click the bar's notification icon |
| Do not disturb | Right-click the notification icon |
| Wi-Fi (wlctl) | Super+Shift+N or click the bar's network module |
| Bluetooth (Bluetui) | Super+Shift+B or click the bar's Bluetooth module |
| Audio mixer (Wiremix) | Super+Shift+A or click the bar's volume module |
| Screenshot (Snap) | Print; press again to dismiss the capture overlay |
| Workspace overview (Hyprspace) | Super+Tab |

Meta and Super both refer to the Windows/logo key. Resize Left/Up shrinks the
window's width/height; Right/Down grows it. Tiled resizing respects the layout.
Other existing controls remain unchanged.

wpaperd starts with the graphical session and shuffles images from
`~/Pictures/Wallpapers` (including subfolders) every 15 minutes, without a fade.
Add your images there; `wpaperctl next` advances manually. No placeholder images
are added during activation. Wallpaper images are personal data, not Git files.
Snap and wlctl are pinned in `flake.lock`; Snap's local build is in `packages/snap.nix`.

## Desktop integration

Home Manager creates and registers `Desktop`, `Documents`, `Downloads`, `Music`,
`Pictures`, `Public`, `Templates`, `Videos`, and `Projects`, plus writable
`Pictures/Screenshots` and `Pictures/Wallpapers` subfolders. Snap uses the XDG
Pictures directory and saves under `Screenshots` by default.

Native desktop defaults in `home/jeffreyc/default.nix` select LibreWolf for web
links, HTML, and PDFs; Dolphin for folders; and Alacritty through
`xdg-terminal-exec` for compatible terminal-launching apps. `codex://` links
remain assigned to ChatGPT/Codex. Keep changes declarative rather than editing
the managed `mimeapps.list` in a GUI. Existing unmanaged files are preserved with
Home Manager's backup suffix during the first activation.

The existing GTK/Hyprland portals, polkit agent, and UDisks2 provide file dialogs,
screen sharing, authentication prompts, and removable-drive support. No desktop
bundle or automounter is added. Media-player, mail, office, and general GUI editor
choices remain open; they are not silently filled by extra packages.

`theme/default.nix` defines the shared Monaspace Neon font and point size.
Alacritty, Rofi, Waybar, SwayNC, GTK defaults and KDE UI fonts consume it. CSS uses
points rather than pixels, without changing display scaling. Web content and
applications with their own font settings are not forcibly overridden.
The contrasting Catppuccin Mocha Dark cursor is configured for Hyprland, GTK,
Qt/KDE and X11 in `home/jeffreyc/desktop.nix`; the rest of the theme stays Latte.

## Dolphin

`home/jeffreyc/desktop.nix` generates `kdeglobals` and the `JeffreyLatte.colors`
scheme from `theme/`. The KDE Qt platform plugin and Breeze widget style supply
native controls; Breeze icons are exposed from Dolphin's existing dependencies.
This does not install a Plasma session, System Settings, Konsole, or an indexer.
It also sets the platform/style for other Qt applications, not just Dolphin.

Open Terminal (Shift+F4) uses Alacritty at the viewed location. Dolphin's F4
embedded terminal requires Konsole's separate component and is intentionally not
added. Existing Dolphin preferences, view history, and Places bookmarks remain
writable and unmanaged; selected default apps and theme colors are declarative.
KIO supplies file/trash support and extras. Qt's `kimageformats` adds HEIC/HEIF,
AVIF, JPEG XL, RAW and other image readers; `kdegraphics-thumbnailers` adds PDF/RAW
previews, and `ffmpegthumbs` adds video previews. Toggle **Show Previews** with F12;
individual types remain configurable in Dolphin's preview preferences. Existing
per-folder view settings are preserved.

Gwenview is the default image viewer and quick editor, using the same KDE Latte
theme. It supports crop, resize, rotate, flip, annotation and basic adjustments;
save a copy when preserving an original. It launches on demand, not as a daemon.

Ark supplies native **Extract** and **Compress** context-menu actions and is the
default archive viewer. Use **Extract here** or **Extract to…** to unpack files;
select files/folders and use **Compress to…** to create an archive. These are
Ark's upstream service menus, not custom shell actions. Ark shares the KDE Latte
theme. The maintained 7-Zip backend provides both `7zz` and the `7z` name required
by this pinned Ark version. ZIP and tar formats use Ark's native libraries;
7z uses the external backend. No archive daemon is added. Archives from untrusted
sources should be extracted into a fresh destination, not over important files.

After activation, use a newly started Dolphin process for the new Qt environment.
Existing windows are not force-closed. A fresh login also picks up the declarative
Qt session settings.

## First activation

Review the diff and evaluate before switching:

```bash
nix flake check --show-trace
sudo nixos-rebuild dry-build --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos
```

Home Manager is integrated into the NixOS configuration; a separate `home-manager switch` is not required.

The first activation may preserve a conflicting user file with the suffix `.hm-backup`. After confirming the managed version, remove the backup manually.

## Routine maintenance

```bash
nix flake update
nix flake check
sudo nixos-rebuild switch --flake .#nixos
git add flake.lock
git commit -m "chore: update flake inputs"
```

Roll back from the boot menu or with `sudo nixos-rebuild switch --rollback` if a generation misbehaves.

## Graphical Codex

The official ChatGPT desktop app includes graphical Codex and is installed
alongside the CLI. Open **ChatGPT** from Rofi or run `chatgpt`, then sign in with
your ChatGPT account. Both clients are pinned through the unstable flake input.

## Tailscale

`services.tailscale.enable` in `modules/nixos/core.nix` installs the CLI and starts
`tailscaled` as a system service. After activation, authenticate interactively:

```bash
sudo tailscale up
tailscale status
```

No authentication keys are stored in this repository. Tailscale SSH, subnet
routing, and exit-node configuration are not enabled here.

## GitHub

The existing `origin` remote is
[AldogPlays/nixos-config](https://github.com/AldogPlays/nixos-config).
After reviewing and validating changes:

```bash
git add <files>
git commit -m "Describe the configuration change"
git push origin main
```

Review files for host-specific or sensitive information before publishing them.
Disk UUIDs are identifiers rather than encryption secrets, but this repository
intentionally documents the machine model and storage layout.

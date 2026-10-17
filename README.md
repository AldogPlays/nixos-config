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
theme/                        shared Latte color foundation (not integrated yet)
docs/system-context.md        system inventory and configuration decisions
docs/audit.md                 bootstrap hardware/configuration audit
```

The fixed Catppuccin Latte theme foundation is documented in
[theme/README.md](theme/README.md). Application integration is pending component
research; the foundation currently has no effect on the desktop.

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

wpaperd starts with the graphical session and uses a packaged dark-gray NixOS
wallpaper as a placeholder. Change `services.wpaperd.settings.default.path` in
`home/jeffreyc/desktop.nix` to select a different persistent wallpaper. Snap and
wlctl are pinned in `flake.lock`; Snap's local build is in `packages/snap.nix`.

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

# NixOS configuration

Flake-based NixOS and Home Manager configuration for the `nixos` host (Lenovo IdeaPad 5 2-in-1 14AKP10) and user `jeffreyc`.
The bootstrap app also generates installation-specific hosts for other x86-64 PCs.

## Layout

```text
AGENTS.md                     working directions for agents
flake.nix                     pinned inputs and host output
hosts/nixos/                  machine identity, disks, and boot hardware
modules/nixos/                reusable OS, hardware, and desktop modules
home/jeffreyc/                Home Manager modules
packages/                     local Nix packages (Snap, wallpaper-only hyprmosaic)
scripts/                      portable bootstrap and host inventory reader
bootstrap/                    generated-host templates
dotfiles/hypr/                versioned Hyprland configuration
theme/                        shared Latte palette, semantic roles, adapter contract
tests/                        wallpaper policy and Lua scheduling regression tests
docs/system-context.md        system inventory and configuration decisions
docs/wallpapers.md            workspace wallpaper design, cache and troubleshooting
docs/audit.md                 bootstrap hardware/configuration audit
```

The fixed Catppuccin Latte theme is documented in
[theme/README.md](theme/README.md). Hyprland borders, Alacritty, Rofi, Waybar,
SwayNC, Dolphin/KDE Qt colors, GTK3/GTK4 colors, SDDM and hyprlock consume the
shared palette. Remaining coverage and exceptions are documented there.

## Desktop controls

| Action | Shortcut or control |
| --- | --- |
| Terminal (Alacritty) | Meta+T |
| New LibreWolf window | Meta+F |
| Close focused window | Meta+Q |
| Toggle floating | Meta+W |
| Toggle focused tile split (top/bottom ↔ side-by-side) | Meta+J |
| Toggle fullscreen | Alt+Enter |
| Workspace 1–10 | Meta+1–9, Meta+0 for 10 |
| Move window to workspace | Meta+Shift+1–9 or 0 |
| Focus window in a direction | Ctrl+Meta+Arrow; hold to repeat |
| Move focused window | Meta+Arrow; tiled layout move or 20 px floating move, hold to repeat |
| Resize focused window | Meta+Shift+Arrow; 20 px steps, hold to repeat |
| File browser (Dolphin) | Meta+E |
| App launcher (Rofi) | Meta+A |
| Notification center (SwayNC) | Super+N or click the bar's notification icon |
| Do not disturb | Right-click the notification icon |
| Wi-Fi (wlctl) | Super+Shift+N or click the bar's network module |
| Bluetooth (Bluetui) | Super+Shift+B or click the bar's Bluetooth module |
| Audio mixer (Wiremix) | Super+Shift+A or click the bar's volume module |
| Screenshot (Snap) | Print; press again to dismiss the capture overlay |

Meta and Super both refer to the Windows/logo key. Resize Left/Up shrinks the
window's width/height; Right/Down grows it. Tiled resizing respects the layout.
Floating windows move and resize in pixel increments instead of snapping to
screen edges. Mouse snapping is disabled. Waybar has top/side margins matching
the compact outer window gaps, rounded corners and a thin 1px border; it still
reserves space above tiled windows rather than covering them.
It hides when the focused workspace has no tiled windows, but appears while
Rofi is open. Floating dialogs and PiP do not count as tiles. Closing Rofi
restores the workspace-based visibility. Native Hyprland Lua events control the
existing Waybar process; there is no extra daemon or polling loop. When hidden,
Waybar releases its reserved space. The policy follows the focused monitor and
its active special workspace when one is open.
Other existing controls remain unchanged.
The cursor hides after five seconds without pointer activity and reappears on
movement. This is Hyprland's native timeout, not a separate idle service.

hyprmosaic draws each workspace's remembered random image from
`~/Pictures/Wallpapers`, including subfolders. Wallpapers slide with their
workspaces instead of changing underneath them. Assignments refresh every
quarter-hour, without wallpaper-based theme changes. Display-sized copies are
prepared ahead of time; originals remain untouched and outside Git.
A bounded 512 MiB cache in `~/.cache/workspace-wallpapers` reuses the exact
prepared images across logins and later refreshes, warming automatically on use.
See [workspace wallpapers](docs/wallpapers.md) for implementation, cache limits,
supported formats, and troubleshooting.

Snap and wlctl are pinned in `flake.lock`; Snap's local build is in `packages/snap.nix`.

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

Frosted glass applies to normal application windows, Rofi and SwayNC.
`theme/default.nix.material` controls their shared background opacity and
Hyprland blur settings. `material.focusedOpacity` makes focused windows fully
opaque; unfocused windows use `material.unfocusedOpacity` (95% opacity), and
fullscreen is fully opaque. Shell backplates use `material.opacity` (90%).
Explicitly marked modal dialogs and recognized LibreWolf/Firefox picture-in-picture
windows stay fully opaque; recognized PiP windows float at a compact initial size,
without forcing position or pin state. Manual resizing remains available; a
config reload reapplies the default once. PiP matching uses the browser class and
exact English `Picture-in-Picture` title; other apps/localizations may need
additional verified identifiers. Unmarked dialogs cannot be identified
generically by this rule.
Hyprland affects the whole surface, including text, images and video; native
terminal alpha stays at 1.0 to avoid double transparency. Waybar uses a fully
opaque shared Latte background, independent of window focus. The login screen
stays opaque.
Windows have 1px borders: the shared focus color when active and muted border
color when inactive. Rofi's outer frame and the notification-center frame remain
borderless; useful control outlines and separators remain. This is matte blur,
without glossy gradients or refraction.
The existing NixOS generation rollback command below restores the previous
active configuration; returning the repository to the earlier design is a
separate Git change, so a future rebuild does not reapply an unwanted trial.

## GTK, login and lock screens

GTK3 uses `adw-gtk3` for widget structure with generated Latte named colors;
GTK4/libadwaita keeps its native layout with generated color variables. Both
adapters live in `home/jeffreyc/desktop.nix`. The light appearance preference is
also declared through the existing GTK/Home Manager integration. No GNOME session,
theme daemon or independent Catppuccin palette is installed. Legacy GTK2 colors,
sandboxed apps without access to host configuration, and apps overriding their
own styling are not covered by these adapters. Reopen apps that cache styling.

SDDM remains the login manager. `modules/nixos/hyprland.nix` configures the pinned
minimal `where-is-my-sddm-theme` layout using our shared colors, font and cursor.
The username and session are visible; type your password and press Enter.
F1 shows its keyboard help, F2 cycles users and F3 cycles sessions. Its power
shortcuts are F10 suspend, F11 power off and F12 reboot. The new greeter takes
effect when SDDM next starts, normally on your next boot; do not restart the
display manager mid-session just to preview it.

Meta+L runs hyprlock with a solid, opaque Latte background, username and
thin-bordered password field. No background screenshot, blur or transparency is
configured. Live session-lock xray remains disabled.
Authentication is unchanged. The generated config is in `~/.config/hypr/hyprlock.conf`;
NixOS declares its PAM service for normal password authentication. No auto-lock
timer, idle daemon or authentication grace period is added. Test unlocking at a
convenient time; configuration checks do not prove a successful password unlock.

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

On a fresh **x86-64 NixOS 26.05 installation**, run as the existing desktop user
after enabling access to this private GitHub repository:

```bash
nix --extra-experimental-features 'nix-command flakes' run 'git+ssh://git@github.com/AldogPlays/nixos-config?ref=main#bootstrap' -- --apply
```

This remote command requires the bootstrap changes to have been pushed. From an
existing checkout, use `nix run .#bootstrap -- --apply`. Omit `--apply` for a preview;
add `--output /tmp/project-host-preview` to save the generated files for review.
Both modes use the project's locked inputs. SSH access to GitHub is a prerequisite,
not a credential embedded in Nix. Run from an installed system, not the live ISO.

The app reads `/etc/nixos/configuration.nix` using the pinned NixOS modules, copies
that installation's `hardware-configuration.nix`, and preserves the existing
normal user's login/home, hostname, system compatibility baseline, initrd style,
systemd-boot or GRUB/EFI settings, and graphics-driver selection. It carries standard
NVIDIA branch/PRIME settings and standard VA-API driver extras when configured,
including 32-bit graphics support; it does not auto-select a proprietary
driver for unconfigured hardware. It never partitions/formats disks or copies this
Lenovo's UUIDs. The shared desktop and persistent wallpaper cache are included.
Existing mutable-account passwords remain on the installation; personal files,
wallpapers and application logins must be restored separately.

With `--apply`, it builds the complete system **before** privileged writes, backs
up `/etc/nixos` to `/etc/nixos.pre-project-TIMESTAMP`, then installs a local host
flake plus lock, JSON settings and copied hardware module. The original
`configuration.nix` and `hardware-configuration.nix` remain untouched. Activation
may replace the current display manager/session; no automatic reboot is performed.
For systemd-boot it also clears the persistent EFI menu-timeout override when EFI
variables are writable, so the declared zero-second timeout takes effect.

The generated host pins the exact project source snapshot in the Nix store.
Its `/etc/nixos-project-source` link retains that snapshot through the system
closure so garbage collection cannot remove the private source needed to rebuild.
`rebuild` then uses `/etc/nixos#nixos`; rerun bootstrap from an updated project
revision to adopt later project changes. Reruns recognize the generated host and
back up its current state again. A newer installed NixOS release or compatibility
baseline than the pinned release,
an unrelated existing flake, immutable accounts, custom Secure Boot/mirrored GRUB,
or custom graphics package requires an explicit migration; bootstrap stops before
changing it. `--configuration`/`--hardware` can select alternative input files for
previewing a conventional host. Arbitrary relative imports need a host module.

Portable tests evaluate complete Intel/UEFI, AMD/BIOS GRUB and NVIDIA host
configurations and check user/disk isolation. They do not prove boot or GPU
behavior on every physical PC. The bootstrap has been exercised in preview mode
on this laptop; its fresh-install activation path still needs a VM or spare-PC
trial before being called deployment-tested.

For the original Lenovo host, use the repository's existing target:

Review the diff and evaluate before switching:

```bash
nix flake check --show-trace
sudo nixos-rebuild dry-build --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos
```

Home Manager is integrated into the NixOS configuration; a separate `home-manager switch` is not required.

The first activation may preserve a conflicting user file with the suffix `.hm-backup`. After confirming the managed version, remove the backup manually.

## Routine maintenance

Starship supplies a minimal single-line Bash prompt: directory, Git branch/status
when applicable, and an arrow that changes color after a failed command. Its
settings are declared in `home/jeffreyc/programs.nix`, using shared theme roles;
the generated file is `~/.config/starship.toml`. Open a new terminal after
activation to initialize it, or run `exec bash` at an idle shell prompt. No new
background service is added.

### Shell conveniences

Interactive Bash uses ble.sh for syntax highlighting, completion menus and
grey/italic suggestions from local history and normal shell completion. Press
Tab to accept a visible suggestion (Right Arrow also works at the end of the
line); without a suggestion, Tab performs ordinary completion. Enter executes
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

```bash
nix flake update
nix flake check
sudo nixos-rebuild switch --flake .#nixos
git add flake.lock
git commit -m "chore: update flake inputs"
```

Roll back from the boot menu or with `sudo nixos-rebuild switch --rollback` if a generation misbehaves.

The boot menu has no countdown. Hold Space during firmware startup to open it
and select a recovery generation. If a timeout previously set in the boot menu
persists after a rebuild, clear its EFI override with `sudo bootctl set-timeout ''`.

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

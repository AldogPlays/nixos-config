# Shared theme foundation

Status: native adapters cover Hyprland borders, Alacritty, Rofi, Waybar,
SwayNC, Dolphin/KDE Qt colors, GTK3/GTK4, SDDM and hyprlock. This is not yet a claim
that the entire desktop is themed.

This is a fixed Catppuccin Latte theme. The palette is plain Nix data with no
additional flake inputs, selectors, generated runtime state, or background
services. App adapters may install their native styling plugins.

## Source of truth

- `palettes/latte.nix` contains all 26 official Latte colors from
  [Catppuccin palette v1.8.0](https://github.com/catppuccin/palette/blob/v1.8.0/palette.json).
  The upstream project uses the [MIT license](https://github.com/catppuccin/palette/blob/v1.8.0/LICENSE).
  Values are stored locally and versioned in Git; builds do not fetch a palette.
- `default.nix` is the public entry point. It exports `name`, `variant`,
  `appearance`, `palette`, `roles`, `typography`, `cursor`, and `material`. Every color is an opaque lowercase
  `#rrggbb` string.
- `roles` assigns colors to purposes. These assignments are our starting choices,
  not an official Catppuccin application theme. Adjust a shared role here instead
  of changing the upstream palette or copying hex values into app configuration.

| Role | Palette entry | Intended use |
| --- | --- | --- |
| `background` | `base` | Main background |
| `backgroundAlt` | `mantle` | Alternate background |
| `surface` | `surface0` | Controls and distinct surfaces |
| `foreground` | `text` | Primary text |
| `foregroundMuted` | `subtext1` | Secondary text |
| `accent` | `blue` | Main highlight |
| `border` | `surface1` | Unfocused borders and separators |
| `borderFocused` | `blue` | Focus indication |
| `selection` | `surface0` | Selection background |
| `success` | `green` | Success indication |
| `warning` | `yellow` | Warning indication |
| `error` | `red` | Error indication |
| `info` | `sapphire` | Information indication |

## Adapters

Each component's existing Nix module imports this directory and translates
the shared roles into the app's native settings:

```nix
let
  theme = import ../../theme;
in
  theme.roles.background
```

The relative import above matches the Home Manager modules two directories below
the repository root.

Adapters should consume `roles` for common UI colors. Use `palette` directly
when a feature needs named colors, such as syntax highlighting. Keep shared role
assignments here and app-specific formatting in the adapter. Add reusable format
helpers only when an actual integration needs them.

Keep alpha separate from the canonical colors. An adapter can strip `#`, append
an alpha channel, or generate the required syntax; it should not invent a second
set of Latte values. Document unavoidable exceptions, including packaged assets
that cannot consume individual colors. Check readability for each actual use;
membership in the palette alone does not establish sufficient text contrast.

`typography` holds the shared UI font family and point size. Alacritty, Rofi,
Waybar, SwayNC, GTK defaults and KDE UI font roles translate these into native
settings; CSS uses `pt` rather than `px`. Website fonts and independent app
overrides are not forced. Spacing, borders and rounding remain app-specific.
Integrations follow normal rebuild and app reload/restart behavior.
No runtime refresh or switching mechanism is planned.

## Integration research (2026-10-16)

Reference ports were inspected outside the repository under `/tmp`; they are not
vendored, imported, added to the lock file, or used as build dependencies. These
links document research, not an instruction to fetch themes during activation.

| Component | Native integration and reference |
| --- | --- |
| Alacritty | `programs.nix`: TOML `colors` groups from the [app documentation](https://alacritty.org/config-alacritty.html), with ANSI/indexed mapping informed by the [Catppuccin port](https://github.com/catppuccin/alacritty/tree/f6cb5a5c2b404cdaceaff193b9c52317f62c62f7). Shared roles deliberately control cursor, search, and selection instead of copying port-specific choices. |
| Starship | `programs.nix`: native TOML styles consume shared roles directly for directory, Git context and prompt character. [Upstream configuration](https://starship.rs/config/) and the [Catppuccin reference](https://github.com/catppuccin/starship) informed the adapter; no preset or second palette is installed. |
| Shell tools | `programs.nix`: ble.sh ghost text, selection and common syntax faces use shared roles; remaining native ANSI faces inherit terminal colors. [ble.sh](https://github.com/akinomyoga/ble.sh) documents completion and initialization. Eza's [native YAML theme](https://github.com/eza-community/eza/blob/main/docs/theme.yml) maps file kinds and Git states to roles. Delta's native styles use shared roles, with syntax themes disabled; [upstream docs](https://dandavison.github.io/delta/configuration.html) and the [Catppuccin reference](https://github.com/catppuccin/delta) informed the adapter. No copied theme files or palette cache are installed. |
| Rofi | `programs.nix`: generated native Rasi layered over Rofi's default layout. [Rasi documentation](https://github.com/davatorium/rofi/blob/next/doc/rofi-theme.5.markdown) and the [reference port](https://github.com/catppuccin/rofi/tree/71fb15577ccb091df2f4fc1f65710edbc61b5a53) informed normal/active/urgent and selected/alternate state coverage. |
| Waybar | `desktop.nix`: native GTK3 CSS; [upstream styling manual](https://github.com/Alexays/Waybar/blob/master/man/waybar-styles.5.scd.in) and [reference port](https://github.com/catppuccin/waybar/tree/ee8ed32b4f63e9c417249c109818dcc05a2e25da). Colors are interpolated directly, without importing a second palette file. |
| SwayNC | `desktop.nix`: GTK4 custom properties from the pinned 0.12.6 package's default stylesheet, plus targeted title/DND/action styling. The [reference port](https://github.com/catppuccin/swaync/tree/f09852bfa35d50e763ae967c26dbe524b9e9f305) informs state coverage, not a copied replacement stylesheet. [Upstream project](https://github.com/ErikReider/SwayNotificationCenter) documents native styling. Default structural CSS remains loaded by SwayNC. |
| Hyprland | `desktop.nix` renders role colors into the Lua source's explicit placeholders, using the pinned 0.55.4 parser/API and the [Lua reference port](https://github.com/catppuccin/hyprland/tree/9f03f26fc10a00e00ec6b2ac2a41e44d16297548) for color-format guidance. Placeholders must not be substituted with a generic variable expander: audio bindings contain unrelated `@DEFAULT_AUDIO_SINK@` tokens. |
| Dolphin/KDE Qt | `desktop.nix` generates KDE RGB color groups in `kdeglobals` and `color-schemes/JeffreyLatte.colors`. Group coverage was researched from the [KDE reference port](https://github.com/catppuccin/kde/tree/6606b5179cfc1e9ba5c3b6b70e15c468e2dddca2); behavior/terminal keys were checked against pinned Dolphin 26.04.3/KIO 6.26.0 sources and the [Dolphin handbook](https://docs.kde.org/trunk_kf6/en/dolphin/dolphin/configuring-dolphin.html). Selection uses our readable shared selection/text roles rather than the port's separate accent/white palette choice. The Qt platform plugin and Breeze widget style are native rendering dependencies, not a second Latte palette. |
| GTK3/GTK4 | `desktop.nix` translates one semantic color map into GTK named colors and GTK4 CSS variables. Pinned [adw-gtk3](https://github.com/lassekongo83/adw-gtk3) provides GTK3 structure; GTK4/libadwaita retains its native layout. [Libadwaita's CSS-variable documentation](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/css-variables.html) and the pinned adw-gtk3 CSS determine coverage. The [archived Catppuccin GTK port](https://github.com/catppuccin/gtk) was researched but is not installed or vendored. |
| SDDM | `modules/nixos/hyprland.nix` uses the pinned [where-is-my-sddm-theme](https://github.com/stepanzubkov/where-is-my-sddm-theme/tree/v1.12.0) layout and native settings, with fail-fast substitutions for hardcoded selection/failure colors and a static thin error outline. [SDDM's theming API](https://github.com/sddm/sddm/wiki/Theming) and the [Catppuccin reference port](https://github.com/catppuccin/sddm) informed research; the latter is not a build dependency. |
| Hyprlock | Home Manager generates native settings from roles and typography, checked against pinned 0.9.5 source, [upstream documentation](https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/) and the [Catppuccin reference](https://github.com/catppuccin/hyprlock). No copied palette, wallpaper reader, command-driven clock or refresh service is needed. PAM is declared separately in the NixOS desktop module. |

`material` supplies focused/unfocused opacity values and Hyprland blur parameters
for frosted glass. Alacritty's native alpha stays at 1.0; a general
Hyprland rule applies to normal application windows, using `focusedOpacity`
when focused (1.0), `unfocusedOpacity` when unfocused (0.95) and 1.0 in fullscreen.
Shell backplates use `opacity` (0.90). This affects text,
images and video as well as the background, without a focus-watching daemon.
Later exceptions keep explicitly modal windows and recognized Firefox-family
PiP opaque; recognized PiP also floats with a compact initial size, no forced
placement/pinning, and manual resizing afterward. A config reload reapplies
the initial size once; subsequent metadata updates do not reset manual resizing.
PiP matching is class-scoped with the exact English title from
[Mozilla's player localization](https://github.com/mozilla-firefox/firefox/blob/main/toolkit/locales/en-US/toolkit/pictureinpicture/pictureinpicture.ftl).
Other apps/localizations and unmarked dialogs require verified additional matches;
do not treat every floating window as a dialog or PiP window.
Native compositor open/title/class/reload callbacks cover delayed PiP metadata
and windows already open during reload, since floating rules only apply at map
time. A one-shot next-loop callback waits for the metadata update to finish.
Rofi uses `#rrggbbaa`; SwayNC uses native RGBA CSS. Waybar deliberately uses the
opaque shared background role, without applying the glass opacity. Rofi's unselected
rows remain transparent to avoid stacking opaque fills over its backplate.
Hyprland layer blur is limited to the exact Waybar, Rofi and SwayNC namespaces,
ignoring fully transparent regions. Alacritty uses normal window background blur.
These translations do not alter canonical palette colors. Shell text stays
opaque; normal application content follows its window's opacity.

Global window opacity remains 1.0, with the scoped rules above overriding
it. Shadows remain disabled. Modal/PiP exceptions and SDDM stay opaque.
Hyprlock uses the opaque shared background role directly, without applying
material opacity, blur or a background screenshot. Session-lock xray remains
disabled; its text and password field are also opaque.
Frosted surfaces deliberately pick up some tint
from the blurred content behind them; this is not a claim that displayed pixels
always equal the canonical palette. No gloss gradients, refraction, distortion,
shader plugins or new services are used. Geometry stays in the existing modules.
Some ANSI colors are intentionally faint
for terminal compatibility, not intended as default body-text colors.
The shared secondary-text and selection roles use `subtext1` and `surface0`:
primary text on the selection background is about 5.17:1, rather than the
starting `surface2` assignment's 3.69:1. Yellow warning states use a border with
normal text rather than low-contrast yellow body text on the light bar.

Not integrated yet: legacy GTK2 colors, Qt clients that ignore the KDE palette,
LibreWolf, Snap, and app-specific TUI themes. Personal wallpaper images are
deliberately independent of the palette; see
[workspace wallpapers](../docs/wallpapers.md). Terminal apps inherit Alacritty's
ANSI palette where they use terminal colors; apps emitting their own truecolor
values need separate research. Do not call those apps fully themed just because
their terminal is.

Gwenview and Ark reuse the KDE adapter. The cursor is an explicit packaged-asset
exception: [Catppuccin cursors](https://github.com/catppuccin/cursors) Mocha Dark
from the pinned nixpkgs package, selected for contrast on the light desktop.
The same package contains native Hyprcursor and Xcursor assets; Home Manager
also sets GTK/X11 defaults and KDE's `kcminputrc`. `cursor` supplies its shared
name/size to both the user session and greeter. No application Mocha palette
or runtime theme coordinator is introduced. Sandboxed applications that cannot
read host settings and apps with their own CSS may not follow the GTK adapter.

Activation uses the normal NixOS/Home Manager switch. Alacritty normally reloads
its config; Rofi uses it on the next invocation; Waybar and SwayNC are managed by
their existing session services. Hyprland's managed Lua file reloads without
restarting the compositor. No extra service coordinates theme changes.

## Inspect without activation

From the repository root:

```bash
nix-instantiate --eval --strict --json theme
```

The active Home Manager modules import this data, so ordinary flake evaluation
now exercises the adapters as well. Native parser/runtime checks are still needed;
a Nix evaluation alone does not establish that an application's styling is valid.

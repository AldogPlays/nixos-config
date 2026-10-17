# Shared theme foundation

Status: first native adapters cover Hyprland borders, Alacritty, Rofi, Waybar,
and SwayNC. This is not yet a claim that the entire desktop is themed.

This is a fixed Catppuccin Latte theme. It is plain Nix data with no additional
packages, flake inputs, selectors, generated runtime state, or background services.

## Source of truth

- `palettes/latte.nix` contains all 26 official Latte colors from
  [Catppuccin palette v1.8.0](https://github.com/catppuccin/palette/blob/v1.8.0/palette.json).
  The upstream project uses the [MIT license](https://github.com/catppuccin/palette/blob/v1.8.0/LICENSE).
  Values are stored locally and versioned in Git; builds do not fetch a palette.
- `default.nix` is the public entry point. It exports `name`, `variant`,
  `appearance`, `palette`, and `roles`. Every color is an opaque lowercase
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

Fonts, spacing, borders, and rounding remain in their existing configurations
until there is a concrete reason to share them. This foundation defines colors.
Integrations follow normal rebuild and app reload/restart behavior.
No runtime refresh or switching mechanism is planned.

## Integration research (2026-10-16)

Reference ports were inspected outside the repository under `/tmp`; they are not
vendored, imported, added to the lock file, or used as build dependencies. These
links document research, not an instruction to fetch themes during activation.

| Component | Native integration and reference |
| --- | --- |
| Alacritty | `programs.nix`: TOML `colors` groups from the [app documentation](https://alacritty.org/config-alacritty.html), with ANSI/indexed mapping informed by the [Catppuccin port](https://github.com/catppuccin/alacritty/tree/f6cb5a5c2b404cdaceaff193b9c52317f62c62f7). Shared roles deliberately control cursor, search, and selection instead of copying port-specific choices. |
| Rofi | `programs.nix`: generated native Rasi layered over Rofi's default layout. [Rasi documentation](https://github.com/davatorium/rofi/blob/next/doc/rofi-theme.5.markdown) and the [reference port](https://github.com/catppuccin/rofi/tree/71fb15577ccb091df2f4fc1f65710edbc61b5a53) informed normal/active/urgent and selected/alternate state coverage. |
| Waybar | `desktop.nix`: native GTK3 CSS; [upstream styling manual](https://github.com/Alexays/Waybar/blob/master/man/waybar-styles.5.scd.in) and [reference port](https://github.com/catppuccin/waybar/tree/ee8ed32b4f63e9c417249c109818dcc05a2e25da). Colors are interpolated directly, without importing a second palette file. |
| SwayNC | `desktop.nix`: GTK4 custom properties from the pinned 0.12.6 package's default stylesheet, plus targeted title/DND/action styling. The [reference port](https://github.com/catppuccin/swaync/tree/f09852bfa35d50e763ae967c26dbe524b9e9f305) informs state coverage, not a copied replacement stylesheet. [Upstream project](https://github.com/ErikReider/SwayNotificationCenter) documents native styling. Default structural CSS remains loaded by SwayNC. |
| Hyprland | `desktop.nix` renders role colors into the Lua source's explicit placeholders, using the pinned 0.55.4 parser/API and the [Lua reference port](https://github.com/catppuccin/hyprland/tree/9f03f26fc10a00e00ec6b2ac2a41e44d16297548) for color-format guidance. Placeholders must not be substituted with a generic variable expander: audio bindings contain unrelated `@DEFAULT_AUDIO_SINK@` tokens. |

Bar backgrounds and window opacity are opaque; shadows remain disabled. This
prevents the wallpaper from tinting the generated colors. Existing geometry and
fonts stay in their existing modules. Some ANSI colors are intentionally faint
for terminal compatibility, not intended as default body-text colors.
The shared secondary-text and selection roles use `subtext1` and `surface0`:
primary text on the selection background is about 5.17:1, rather than the
starting `surface2` assignment's 3.69:1. Yellow warning states use a border with
normal text rather than low-contrast yellow body text on the light bar.

Not integrated yet: GTK/Qt application chrome (including Dolphin), LibreWolf,
SDDM, hyprlock, Hyprspace-specific appearance, Snap, app-specific TUI themes, and
wpaperd's wallpaper image. Terminal apps inherit Alacritty's ANSI palette where
they use terminal colors; apps emitting their own truecolor values need separate
research. Do not call those apps fully themed just because their terminal is.

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

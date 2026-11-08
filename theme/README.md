# Shared theme foundation

Status: native adapters cover Hyprland borders, Alacritty, Rofi, Waybar,
SwayNC, Dolphin/KDE Qt colors, darktable, GTK3/GTK4, Plymouth, SDDM and hyprlock. This is not
yet a claim that the entire desktop is themed.

Catppuccin Latte is selected by default; a dark Monochrome preset is also available.
The adapter contract uses semantic
roles, standard terminal slots and syntax purposes rather than Catppuccin keys.
Theme data stays plain Nix, with no additional flake inputs or background
switching service. An on-demand Rofi menu changes the selection through a normal
NixOS rebuild. App adapters may install their
native styling plugins.

## Choose a theme

Open **Theme Selector** from the app launcher or press **Meta+Ctrl+T** for the
system theme menu. Both launch `theme-menu`. **Active** identifies the
running system's theme, independently of unapplied file edits. Escape cancels;
selecting the active theme makes no change. Selecting another theme opens
Alacritty for the build and normal sudo authentication. The rebuild includes
other saved configuration edits. It does not commit, push or reboot.

The app launcher and system theme menu share the same generated Rasi stylesheet:
background, foreground, selection, font, border and spacing all follow the
selected preset. **Active** is a text label; the theme menu uses the launcher's
normal selection colors rather than a separate active-row highlight.

The helper runs only when invoked. It builds before activation, prevents duplicate
switches, and restores the previous selection after a failed build or cancelled
authentication while the old theme remains active. Concurrent edits are left
untouched. If activation starts but fails, inspect the terminal output before
retrying; configuration restoration does not undo partially restarted services.

On the reference host the menu updates [selection.nix](selection.nix), preserving
the wallpaper override and comments. Manual selection uses the same file:

```nix
{
  preset = "monochrome"; # "latte" or "monochrome"
  wallpaperMode = "theme";
}
```

`wallpaperMode = "theme"` uses color wallpapers for Latte and grayscale for
Monochrome. Set it to `"color"` or `"grayscale"` to choose independently of the
desktop preset. The setting affects prepared wallpaper copies; original images
are never edited. No automatic theme schedule or resident switching service is installed.

Validate and rebuild through the normal [maintenance workflow](../docs/maintenance.md).
Changing this file alone does not update the desktop. Reopen applications that
cache their appearance. A fresh login or reboot refreshes the whole session;
Plymouth uses the selected theme on the next boot. A reboot is not performed by
the rebuild command.

On a bootstrap-generated host, the menu updates `themeSelection` in
`/etc/nixos/project-host.json` and rebuilds that host. Manual selection uses the
same two fields in that JSON object. Missing overrides default to the pinned
project's selection. Bootstrap reruns preserve this local choice. A normal
`/etc/nixos` rebuild keeps the pinned project snapshot; do not edit the Nix store.

Monochrome keeps the same typography, spacing, borders and blur settings, with
charcoal backgrounds, gray surfaces and white/gray foregrounds. Its terminal and
syntax slots are grayscale too. The pointer uses the small `vanilla-dmz` asset
package's DMZ White theme. Packaged artwork, website content and applications listed
under coverage limits can still contain color. Status meanings retain their
icons and labels; their shared theme colors are shades of gray.

## Source of truth

- `selection.nix` chooses the preset and optional wallpaper override.
- `presets.nix` registers the available theme IDs and their data. The menu's
  choices are generated from this registry. `load.nix` resolves a selection;
  `default.nix` supplies the reference-host default.
- `latte.nix` and `monochrome.nix` define preset colors, appearance, cursor and
  default wallpaper mode. `common.nix` holds shared typography, icon assets,
  geometry and material settings.
- `palettes/latte.nix` contains all 26 official Latte colors from
  [Catppuccin palette v1.8.0](https://github.com/catppuccin/palette/blob/v1.8.0/palette.json).
  The upstream project uses the [MIT license](https://github.com/catppuccin/palette/blob/v1.8.0/LICENSE).
  Values are stored locally and versioned in Git; builds do not fetch a palette.
- `default.nix` is the public entry point. Its adapter contract is `appearance`,
  `roles`, `terminal`, `syntax`, `typography`, `cursor`, `icons`, `geometry`,
  `wallpaper` and
  `material`. Every color is an opaque lowercase `#rrggbb` string. `name` and
  `variant` identify the selected theme; the exported `palette` is reference data,
  not an adapter dependency. A replacement theme need not expose Catppuccin keys.
- `roles` assigns colors to purposes. These assignments describe the selected desktop colors,
  not an official Catppuccin application theme. Adjust a shared role here instead
  of changing the upstream palette or copying hex values into app configuration.

The following table describes Latte's role assignments; Monochrome supplies the
same roles with neutral colors.

| Role | Latte palette entry | Intended use |
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
| `selectionForeground` | `text` | Text on selections |
| `onAccent`, `onSuccess`, `onError` | `base` | Text on the corresponding filled color |
| `onWarning` | `text` | Text on warning fills |
| `onForegroundMuted` | `base` | Text on muted-text-colored search fills |
| `linkVisited` | `mauve` | Visited KDE links |
| `success` | `green` | Success indication |
| `warning` | `yellow` | Warning indication |
| `error` | `red` | Error indication |
| `info` | `sapphire` | Information indication |
| `network`, `bluetooth`, `audio` | `sapphire`, `mauve`, `peach` | Desktop control icon accents |
| `powerPerformance`, `powerBalanced`, `powerSaver` | `maroon`, `teal`, `green` | Power profile icons |
| `notifications` | `mauve` | Notification-center control icon |

## Adapters

The flake resolves the selection once and passes `desktopTheme` to the existing
NixOS and Home Manager modules. They translate its roles into native settings:

```nix
{ desktopTheme, ... }:
let
  theme = desktopTheme;
in
{
  # Use theme.roles.background in the component's native configuration.
}
```

Importing `theme/` directly returns the reference default as plain data. Runtime
adapters must consume the flake's `desktopTheme` argument so portable-host
overrides also reach every component, including the screenshot selection border.

Adapters consume `roles` for common UI colors, `terminal.normal`/`bright` for
standard ANSI slots, `terminal.indexed` for explicit indexed overrides, and
`terminal.viCursor`/`onViCursor` for the terminal's vi-mode cursor. `syntax`
provides `variable`, `parameter` and `function` colors. Map these purposes to the
selected palette here; keep app-specific formatting in the adapter. Do not read
`palette` directly from an application module. Unspecified indexed colors and
application-defined truecolor values remain outside this contract.

`appearance` is `light` or `dark`. It drives GTK's appearance preference, the
matching adw-gtk3 structural variant and Delta's light-mode flag. It does not
calculate a new palette: a dark theme must also supply suitable role values.
Foreground/background pairs are explicit so a future theme can choose readable
text independently of its main background; verify contrast for each new palette.

Generated integration identifiers stay stable: Rofi uses `desktop.rasi`, KDE
uses `JeffreyTheme.colors`/`JeffreyTheme`, and Plymouth uses `jeffrey-theme` with
`dotfiles/plymouth/theme.script`. Their names do not select colors. Renaming
these identifiers does not choose a palette; they stay the same for every preset.

Keep alpha separate from the canonical colors. An adapter can strip `#`, append
an alpha channel, or generate the required syntax; it should not invent a second
set of theme values. Document unavoidable exceptions, including packaged assets
that cannot consume individual colors. Check readability for each actual use;
membership in the palette alone does not establish sufficient text contrast.

`typography` holds the shared UI font family, monospace symbol fallback, point
size, font package paths and boot font file. Package paths such as
`[ "monaspace" "static" ]` are resolved with `lib.getAttrFromPath` against pinned
`pkgs`, keeping the theme import evaluable as plain JSON. Cursor package/name/size
and Qt icon package/name plus GTK symbolic-icon assets are selected here too.
The GTK icon theme is not newly forced; supplying its existing assets preserves
current defaults. Toolkit widget structures (Breeze and adw-gtk3) remain adapter
dependencies rather than independent application palettes.
Alacritty, Rofi, Waybar, SwayNC, GTK defaults and KDE UI font roles translate these
into native settings; CSS uses `pt` rather than `px`. Website fonts and independent app
overrides are not forced. `geometry` supplies common shell border width, rounding,
spacing, padding, overlay insets, icon size and compact control height in logical
pixels. Hyprland, Waybar, Rofi, SwayNC, SwayOSD, GTK4 and the authentication
adapters translate the relevant values into native settings. Plymouth and
hyprlock share password-field dimensions; SDDM retains its native proportional
field width. Font sizes stay in points. Component-specific content widths,
positions and native third-party widget layouts remain in their adapters.
Waybar gives all six status icons the same minimum width and horizontal padding,
with no additional per-icon margins. Its border inset matches the border width.
Notification panel/popups share the outer tile gap; small inner rounding is
derived from the outer radius where needed.
Integrations follow normal rebuild and app reload/restart behavior.
The selection menu initiates the same build/activation workflow; no daemon
coordinates application refreshes.

## Integration references

Adapters generate native application configuration from the shared theme data.
The references below describe the relevant formats and integration choices.
Reference ports are not build dependencies or fetched during activation.

btop's native `desktop.theme` is generated in `home/jeffreyc/programs.nix` from
the same semantic roles as the shell and terminal. Background, text, selection,
outlines, meters and graphs follow both presets; no external monitor palette is
installed. Its square internal outlines preserve the compact terminal layout.

GTK4's settings file uses the symbolic `light`/`dark` color-scheme value. The
pinned Home Manager module emits numeric enums, which the GTK INI parser rejects;
the adapter overrides that field while retaining the normal dconf preference.

| Component | Native integration and reference |
| --- | --- |
| Alacritty | `programs.nix`: TOML `colors` groups from the [app documentation](https://alacritty.org/config-alacritty.html), with ANSI/indexed mapping informed by the [Catppuccin port](https://github.com/catppuccin/alacritty/tree/f6cb5a5c2b404cdaceaff193b9c52317f62c62f7). Shared roles deliberately control cursor, search, and selection instead of copying port-specific choices. |
| Starship | `programs.nix`: native TOML styles consume shared roles directly for directory, Git context and prompt character. [Upstream configuration](https://starship.rs/config/) and the [Catppuccin reference](https://github.com/catppuccin/starship) informed the adapter; no preset or second palette is installed. |
| Shell tools | `programs.nix`: ble.sh ghost text, selection and common syntax faces use shared roles; remaining native ANSI faces inherit terminal colors. [ble.sh](https://github.com/akinomyoga/ble.sh) documents completion and initialization. Eza's [native YAML theme](https://github.com/eza-community/eza/blob/main/docs/theme.yml) maps file kinds and Git states to roles. Delta's native styles use shared roles, with syntax themes disabled; [upstream docs](https://dandavison.github.io/delta/configuration.html) and the [Catppuccin reference](https://github.com/catppuccin/delta) informed the adapter. No copied theme files or palette cache are installed. |
| Rofi | `programs.nix`: generated native Rasi layered over Rofi's default layout. [Rasi documentation](https://github.com/davatorium/rofi/blob/next/doc/rofi-theme.5.markdown) and the [reference port](https://github.com/catppuccin/rofi/tree/71fb15577ccb091df2f4fc1f65710edbc61b5a53) informed normal/active/urgent and selected/alternate state coverage. |
| Waybar | `desktop.nix`: native GTK3 CSS; [upstream styling manual](https://github.com/Alexays/Waybar/blob/master/man/waybar-styles.5.scd.in) and [reference port](https://github.com/catppuccin/waybar/tree/ee8ed32b4f63e9c417249c109818dcc05a2e25da). Colors are interpolated directly, without importing a second palette file. |
| SwayNC | `desktop.nix`: GTK4 custom properties from the pinned 0.12.6 package's default stylesheet, plus compact widget/card spacing, small icons, flat buttons, DND and keyboard-focus styling. The panel keeps its configured height, capped by the monitor; panel and popups share the outer tile gap below the usable screen edge and from the right edge, aligning with tiled windows; notification cards use thin borders, while the panel shares Waybar tooltips’ main background, muted outline, font and rounding, retaining its roomier control spacing. Colors and typography come from this directory; panel and popup backgrounds are opaque like Waybar. The [reference port](https://github.com/catppuccin/swaync/tree/f09852bfa35d50e763ae967c26dbe524b9e9f305) informs state coverage, not a copied replacement stylesheet. [Upstream project](https://github.com/ErikReider/SwayNotificationCenter) documents native styling. Default structural CSS remains loaded by SwayNC. |
| Hyprland | `desktop.nix` renders role colors into the Lua source's explicit placeholders, using the pinned 0.55.4 parser/API and the [Lua reference port](https://github.com/catppuccin/hyprland/tree/9f03f26fc10a00e00ec6b2ac2a41e44d16297548) for color-format guidance. Placeholders must not be substituted with a generic variable expander: audio bindings contain unrelated `@DEFAULT_AUDIO_SINK@` tokens. |
| Dolphin/KDE Qt | `desktop.nix` generates KDE RGB color groups in `kdeglobals` and `color-schemes/JeffreyTheme.colors`. Group coverage was researched from the [KDE reference port](https://github.com/catppuccin/kde/tree/6606b5179cfc1e9ba5c3b6b70e15c468e2dddca2); behavior/terminal keys were checked against pinned Dolphin 26.04.3/KIO 6.26.0 sources and the [Dolphin handbook](https://docs.kde.org/trunk_kf6/en/dolphin/dolphin/configuring-dolphin.html). Selection uses the shared selection/text roles rather than the port's separate accent/white palette choice. The Qt platform plugin and Breeze widget style are native rendering dependencies, not a second Latte palette. |
| GTK3/GTK4 | `desktop.nix` translates one semantic color map into GTK named colors and GTK4 CSS variables. Pinned [adw-gtk3](https://github.com/lassekongo83/adw-gtk3) provides GTK3 structure; GTK4/libadwaita retains its native layout. [Libadwaita's CSS-variable documentation](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/css-variables.html) and the pinned adw-gtk3 CSS determine coverage. The [archived Catppuccin GTK port](https://github.com/catppuccin/gtk) was researched but is not installed or vendored. |
| Darktable | `programs.nix` generates `darktable/themes/desktop.css`, extending the pinned application's native stylesheet with shared interface roles and typography. The `darktable` command and desktop launcher select it through temporary `--conf` overrides without managing mutable preferences or catalogues; headless tools are unchanged. Native neutral image surrounds and functional graph/swatch colors are preserved, including under Monochrome. The general focus-dependent window opacity still applies. The pinned [theme loader](https://github.com/darktable-org/darktable/blob/release-5.4.1/src/gui/gtk.c) defines stylesheet selection and system-font behavior. |
| SDDM | `modules/nixos/hyprland.nix` uses the pinned [where-is-my-sddm-theme](https://github.com/stepanzubkov/where-is-my-sddm-theme/tree/v1.12.0) layout and native settings, with fail-fast substitutions for hardcoded selection/failure colors and a static thin error outline. [SDDM's theming API](https://github.com/sddm/sddm/wiki/Theming) and the [Catppuccin reference port](https://github.com/catppuccin/sddm) informed research; the latter is not a build dependency. |
| Plymouth | `modules/nixos/hyprland.nix` generates a theme for the pinned native script plugin; `dotfiles/plymouth/theme.script` renders prompt, mask and messages. Colors are normalized from shared roles, the initrd includes Monaspace Neon, and the plain field image is generated at build time from shared geometry. Pillow is a build dependency only. No separate Catppuccin theme package, logo or animation is installed. [Plymouth's documentation](https://www.freedesktop.org/wiki/Software/Plymouth/) describes its early-boot role. Boot rendering and successful graphical unlocking still require validation after activation and boot. |
| Hyprlock | Home Manager generates native settings from roles and typography, checked against pinned 0.9.5 source, [upstream documentation](https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/) and the [Catppuccin reference](https://github.com/catppuccin/hyprlock). No copied palette, wallpaper reader, command-driven clock or refresh service is needed. PAM is declared separately in the NixOS desktop module. |

`material` supplies focused/unfocused opacity values and Hyprland blur parameters
for frosted glass. Alacritty's native alpha stays at 1.0; a general
Hyprland rule applies to normal application windows, using `focusedOpacity`
when focused (1.0), `unfocusedOpacity` when unfocused (0.95) and 1.0 in fullscreen.
Rofi's backplate uses `opacity` (0.90). Window opacity affects text,
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
Rofi uses `#rrggbbaa`; Waybar and SwayNC use the opaque shared background role,
without applying the glass opacity. SwayNC popup alpha is 1. Rofi's unselected
rows remain transparent to avoid stacking opaque fills over its backplate.
Hyprland layer blur is limited to the exact Waybar and Rofi namespaces,
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
In Latte, the shared secondary-text and selection roles use `subtext1` and `surface0`:
primary text on the selection background is about 5.17:1, rather than the
starting `surface2` assignment's 3.69:1. Yellow warning states use a border with
normal text rather than low-contrast yellow body text on the light bar.

Not integrated yet: legacy GTK2 colors, Qt clients that ignore the KDE palette,
LibreWolf, Joplin, ChatGPT/Codex, Steam, Modrinth, Packet Tracer, ONLYOFFICE, and app-specific
TUI themes (wlctl, Bluetui, Wiremix and Codex CLI). Lutris and Print Settings may
inherit generic GTK styling; app-specific overrides are not covered.
Personal wallpaper assignments are independent of the palette; an optional
grayscale preparation mode follows the selected theme by default. See
[workspace wallpapers](../docs/wallpapers.md). Terminal apps inherit Alacritty's
ANSI palette where they use terminal colors; apps emitting their own truecolor
values need separate research. A terminal palette alone does not establish full application coverage.

Gwenview and Ark reuse the KDE adapter. The cursor is an explicit packaged-asset
exception: Latte uses [Catppuccin cursors](https://github.com/catppuccin/cursors) Mocha Dark
from the pinned nixpkgs package, selected for contrast on the light desktop.
That package contains native Hyprcursor and Xcursor assets; Monochrome uses
DMZ White's Xcursor assets instead, using Hyprland's
[Xcursor fallback](https://wiki.hypr.land/hypr-ecosystem/user/hyprcursor/). Home Manager
also sets GTK/X11 defaults and KDE's `kcminputrc`. `cursor` supplies its shared
package/name/size to both the user session and greeter. No application Mocha palette
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

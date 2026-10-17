# Shared theme foundation

Status: groundwork only. No application consumes these files yet. Color
integration is deferred until the requested desktop components have been reviewed.

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
| `foregroundMuted` | `subtext0` | Secondary text |
| `accent` | `blue` | Main highlight |
| `border` | `surface1` | Unfocused borders and separators |
| `borderFocused` | `blue` | Focus indication |
| `selection` | `surface2` | Selection background |
| `success` | `green` | Success indication |
| `warning` | `yellow` | Warning indication |
| `error` | `red` | Error indication |
| `info` | `sapphire` | Information indication |

## Future adapters

After a component is chosen for integration, its existing Nix module can import
this directory and translate the shared roles into the app's native settings:

```nix
let
  theme = import ../../theme;
in
  theme.roles.background
```

The relative import above is an example from a module two directories below the
repository root. It is not an adapter or an active module import.

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
Future integrations will follow normal rebuild and app reload/restart behavior.
No runtime refresh or switching mechanism is planned.

## Inspect without activation

From the repository root:

```bash
nix-instantiate --eval --strict --json theme
```

The theme is intentionally not imported by the flake or desktop modules yet, so
ordinary flake checks do not exercise it. New files must be tracked by Git before
a future Git-backed flake integration can use them.

# Shared theme data only; importing this file does not configure applications.
let
  palette = import ./palettes/latte.nix;
in
{
  name = "Catppuccin Latte";
  variant = "latte";
  appearance = "light";

  inherit palette;

  # Personal role choices live here; preserve the official palette above.
  roles = {
    background = palette.base;
    backgroundAlt = palette.mantle;
    surface = palette.surface0;
    foreground = palette.text;
    foregroundMuted = palette.subtext1;
    accent = palette.blue;
    border = palette.surface1;
    borderFocused = palette.blue;
    selection = palette.surface0;
    success = palette.green;
    warning = palette.yellow;
    error = palette.red;
    info = palette.sapphire;
  };
}

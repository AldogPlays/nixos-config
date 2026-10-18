# Shared theme data only; importing this file does not configure applications.
let
  palette = import ./palettes/latte.nix;
in
{
  name = "Catppuccin Latte";
  variant = "latte";
  appearance = "light";

  inherit palette;

  # Point sizes throughout; CSS adapters use pt, not px.
  typography = {
    family = "Monaspace Neon";
    size = 11;
  };

  # Packaged asset exception: a dark pointer for contrast on the light desktop.
  cursor = {
    name = "catppuccin-mocha-dark-cursors";
    size = 24;
  };

  # Shell backplates and normal-window focus opacity; modal/PiP exceptions in Lua.
  material = {
    opacity = 0.90;
    focusedOpacity = 0.95;
    blur = {
      size = 6;
      passes = 1;
      noise = 0.015;
      contrast = 1.0;
      brightness = 1.0;
      vibrancy = 0.0;
    };
  };

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

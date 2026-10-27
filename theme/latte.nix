# Shared theme data only; importing this file does not configure applications.
let
  palette = import ./palettes/latte.nix;
  ansi = {
    black = palette.surface1;
    red = palette.red;
    green = palette.green;
    yellow = palette.yellow;
    blue = palette.blue;
    magenta = palette.pink;
    cyan = palette.teal;
    white = palette.subtext1;
  };
in
import ./common.nix
// {
  name = "Catppuccin Latte";
  variant = "latte";
  appearance = "light";

  inherit palette;

  # Packaged asset exception: a dark pointer for contrast on the light desktop.
  cursor = {
    package = [
      "catppuccin-cursors"
      "mochaDark"
    ];
    name = "catppuccin-mocha-dark-cursors";
    size = 24;
  };

  # Standard terminal slots and syntax purposes hide palette-specific names.
  terminal = {
    normal = ansi;
    bright = ansi // {
      black = palette.surface2;
      white = palette.subtext0;
    };
    indexed = [
      {
        index = 16;
        color = palette.peach;
      }
      {
        index = 17;
        color = palette.rosewater;
      }
    ];
    viCursor = palette.lavender;
    onViCursor = palette.base;
  };

  syntax = {
    variable = palette.mauve;
    parameter = palette.mauve;
    function = palette.mauve;
  };

  wallpaper.mode = "color";

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
    selectionForeground = palette.text;
    onAccent = palette.base;
    onSuccess = palette.base;
    onWarning = palette.text;
    onError = palette.base;
    onForegroundMuted = palette.base;
    linkVisited = palette.mauve;
    success = palette.green;
    warning = palette.yellow;
    error = palette.red;
    info = palette.sapphire;
    # Control icon accents; labels retain the normal foreground for readability.
    network = palette.sapphire;
    bluetooth = palette.mauve;
    audio = palette.peach;
    powerPerformance = palette.maroon;
    powerBalanced = palette.teal;
    powerSaver = palette.green;
    notifications = palette.mauve;
  };
}

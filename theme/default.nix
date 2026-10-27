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
{
  name = "Catppuccin Latte";
  variant = "latte";
  appearance = "light";

  inherit palette;

  # Point sizes throughout; CSS adapters use pt, not px.
  typography = {
    family = "Monaspace Neon";
    symbolsFamily = "Symbols Nerd Font Mono";
    size = 11;
    # Attribute paths in the pinned package set; keep this file plain data.
    package = [
      "monaspace"
      "static"
    ];
    symbolsPackage = [
      "nerd-fonts"
      "symbols-only"
    ];
    bootFontFile = "share/fonts/opentype/MonaspaceNeon-Regular.otf";
  };

  # Packaged asset exception: a dark pointer for contrast on the light desktop.
  cursor = {
    package = [
      "catppuccin-cursors"
      "mochaDark"
    ];
    name = "catppuccin-mocha-dark-cursors";
    size = 24;
  };

  icons = {
    qt = {
      package = [
        "kdePackages"
        "breeze-icons"
      ];
      name = "breeze";
    };
    # Provide the existing symbolic assets without forcing a GTK icon selection.
    gtk.package = [ "adwaita-icon-theme" ];
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

  # Logical pixels shared by our shell adapters; font sizes stay in points.
  geometry = {
    borderWidth = 1;
    radius = 4;
    spacing = 4;
    padding = 6;
    overlayInset = 12;
    iconSize = 16;
    controlHeight = 24;
    passwordWidth = 280;
    passwordHeight = 40;
  };

  # Shell backplates and normal-window focus opacity; modal/PiP exceptions in Lua.
  material = {
    opacity = 0.90;
    focusedOpacity = 1.0;
    unfocusedOpacity = 0.95;
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

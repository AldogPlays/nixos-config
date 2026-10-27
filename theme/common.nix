# Shared typography, assets and geometry for both presets.
{
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

  # Logical pixels shared by the shell adapters; font sizes stay in points.
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
}

selection:
let
  presets = import ./presets.nix;
  theme = presets.${selection.preset} or (throw "Unknown theme preset: ${selection.preset}");
  wallpaperMode =
    if selection.wallpaperMode == "theme" then theme.wallpaper.mode else selection.wallpaperMode;
in
if
  builtins.elem wallpaperMode [
    "color"
    "grayscale"
  ]
then
  theme // { wallpaper.mode = wallpaperMode; }
else
  throw "wallpaperMode must be theme, color or grayscale"

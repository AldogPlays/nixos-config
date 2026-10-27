let
  shades = {
    background = "#181818";
    backgroundAlt = "#101010";
    surface = "#282828";
    foreground = "#eeeeee";
    muted = "#aaaaaa";
    accent = "#dddddd";
    border = "#666666";
    selection = "#444444";
  };
  normal = {
    black = shades.surface;
    red = "#d0d0d0";
    green = "#b8b8b8";
    yellow = "#e0e0e0";
    blue = "#c0c0c0";
    magenta = "#d8d8d8";
    cyan = "#c8c8c8";
    white = shades.foreground;
  };
in
import ./common.nix
// {
  name = "Monochrome";
  variant = "monochrome";
  appearance = "dark";

  # A neutral white pointer, without a desktop bundle.
  cursor = {
    package = [ "vanilla-dmz" ];
    name = "Vanilla-DMZ";
    size = 24;
  };

  wallpaper.mode = "grayscale";

  terminal = {
    inherit normal;
    bright = normal // {
      black = shades.muted;
      white = "#ffffff";
    };
    indexed = [
      {
        index = 16;
        color = "#cccccc";
      }
      {
        index = 17;
        color = "#e0e0e0";
      }
    ];
    viCursor = "#ffffff";
    onViCursor = shades.background;
  };

  syntax = {
    variable = "#d8d8d8";
    parameter = "#d8d8d8";
    function = "#d8d8d8";
  };

  roles = {
    inherit (shades)
      background
      backgroundAlt
      surface
      foreground
      accent
      border
      selection
      ;
    foregroundMuted = shades.muted;
    borderFocused = shades.accent;
    selectionForeground = shades.foreground;
    onAccent = shades.background;
    onSuccess = shades.background;
    onWarning = shades.background;
    onError = shades.background;
    onForegroundMuted = shades.background;
    linkVisited = "#c8c8c8";
    success = "#b8b8b8";
    warning = "#e0e0e0";
    error = "#ffffff";
    info = "#c8c8c8";
    network = "#c0c0c0";
    bluetooth = "#d8d8d8";
    audio = "#cccccc";
    powerPerformance = "#ffffff";
    powerBalanced = "#cccccc";
    powerSaver = "#aaaaaa";
    notifications = "#d8d8d8";
  };
}

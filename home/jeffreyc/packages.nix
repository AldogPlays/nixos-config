{
  config,
  inputs,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  theme = import ../../theme;
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      hyprland
      jq
      slurp
      grim
      wl-clipboard
    ];
    runtimeEnv = {
      SCREENSHOT_DIRECTORY = "${config.xdg.userDirs.pictures}/Screenshots";
      SCREENSHOT_BORDER = "${theme.roles.borderFocused}ff";
    };
    text = builtins.readFile ../../dotfiles/hypr/screenshot.sh;
  };
  # Ark 26.04 invokes `7z`; the maintained upstream package installs `7zz`.
  sevenZip = pkgs.symlinkJoin {
    name = "7zip-${pkgs._7zz.version}";
    paths = [ pkgs._7zz ];
    postBuild = ''
      ln -s ${pkgs._7zz}/bin/7zz "$out/bin/7z"
    '';
  };
in
{
  home.packages = with pkgs; [
    # Desktop applications
    kdePackages.dolphin
    # Dolphin's native Extract/Compress actions; 7zz backs its 7-Zip plugin.
    kdePackages.ark
    sevenZip
    kdePackages.gwenview
    # Qt image readers (including HEIC/HEIF, AVIF, JXL and RAW), plus KIO previews.
    kdePackages.kimageformats
    kdePackages.kdegraphics-thumbnailers
    kdePackages.ffmpegthumbs
    cisco-packet-tracer_9
    pkgsUnstable.joplin-desktop
    lutris
    # Official desktop client, including graphical Codex, from the pinned input.
    pkgsUnstable.chatgpt

    # On-demand TUI controls; NetworkManager, BlueZ, and PipeWire stay in place.
    inputs.wlctl.packages.${pkgs.stdenv.hostPlatform.system}.default
    bluetui
    wiremix

    # Hyprland utilities used by the declarative keybindings/session
    brightnessctl
    hyprpolkitagent
    playerctl
    wl-clipboard
    screenshot

    # Command-line workflow
    fd
    jq
    ripgrep
    tree

    # Keep Codex on the fast-moving pinned nixpkgs input.
    pkgsUnstable.codex
  ];
}

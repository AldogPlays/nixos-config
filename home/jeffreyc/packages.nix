{
  config,
  inputs,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  theme = import ../../theme;
  screenshotSlurp = pkgs.callPackage ../../packages/slurp { };
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      hyprland
      jq
      screenshotSlurp
      grim
      wl-clipboard
      libnotify
    ];
    runtimeEnv = {
      SCREENSHOT_DIRECTORY = "${config.xdg.userDirs.pictures}/Screenshots";
      SCREENSHOT_BORDER = "${theme.roles.borderFocused}ff";
    };
    text = builtins.readFile ../../dotfiles/hypr/screenshot.sh;
  };
  desktopFeedback = pkgs.writeShellApplication {
    name = "desktop-feedback";
    runtimeInputs = with pkgs; [
      brightnessctl
      wireplumber
      swayosd
      jq
      util-linux
    ];
    text = ''
      # Serialize held-key repeats so the displayed value follows the last change.
      exec 9>"''${XDG_RUNTIME_DIR:?}/desktop-feedback.lock"
      flock 9
      action="''${1:?Expected volume-up, volume-down, mute, mic-mute, brightness-up or brightness-down}"
      if [[ "$action" == brightness-* ]]; then
        case "$action" in
          brightness-up) step=5%+ ;;
          brightness-down) step=5%- ;;
          *) exit 2 ;;
        esac
        # Preserve the existing exponential curve and minimum raw brightness.
        brightness=$(brightnessctl -e4 -n2 -m set "$step")
        IFS=, read -r _ _ _ percent _ <<< "$brightness"
        percent="''${percent%%%}"
        progress=$(jq -n --argjson percent "$percent" '$percent / 100')
        icon=display-brightness-symbolic
        label="$percent%"
      else
        device=@DEFAULT_AUDIO_SINK@
        case "$action" in
          volume-up) wpctl set-volume -l 1 "$device" 5%+ ;;
          volume-down) wpctl set-volume "$device" 5%- ;;
          mute) wpctl set-mute "$device" toggle ;;
          mic-mute)
            device=@DEFAULT_AUDIO_SOURCE@
            wpctl set-mute "$device" toggle
            ;;
          *) exit 2 ;;
        esac
        volume=$(wpctl get-volume "$device")
        read -r _ level muted <<< "$volume"
        progress=$(jq -n --argjson level "$level" '$level | [., 1] | min | [., 0] | max')
        percent=$(jq -n --argjson level "$level" '$level * 100 | round')
        label="$percent%"
        # Match Waybar's three equal volume bands.
        if (( percent < 34 )); then
          band=low
        elif (( percent < 67 )); then
          band=medium
        else
          band=high
        fi
        icon="audio-volume-$band-symbolic"
        if [[ "$action" == mic-mute ]]; then
          icon="microphone-sensitivity-$band-symbolic"
        fi
        if [[ "$muted" == '[MUTED]' ]]; then
          icon=audio-volume-muted-symbolic
          if [[ "$action" == mic-mute ]]; then
            icon=microphone-sensitivity-muted-symbolic
          fi
        fi
      fi
      # A renderer failure must not undo or prevent the actual hardware control.
      swayosd-client --custom-icon "$icon" --custom-progress "$progress" \
        --custom-progress-text "$label" || true
    '';
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
    # Small Qt viewer; use the existing Qt6 KDE palette/style integration.
    (qpdfview.override { libsForQt5 = qt6Packages; })
    # Qt image readers (including HEIC/HEIF, AVIF, JXL and RAW), plus KIO previews.
    kdePackages.kimageformats
    kdePackages.kdegraphics-thumbnailers
    kdePackages.ffmpegthumbs
    cisco-packet-tracer_9
    pkgsUnstable.joplin-desktop
    lutris
    modrinth-app
    # Official desktop client, including graphical Codex, from the pinned input.
    pkgsUnstable.chatgpt

    # On-demand TUI controls; NetworkManager, BlueZ, and PipeWire stay in place.
    inputs.wlctl.packages.${pkgs.stdenv.hostPlatform.system}.default
    bluetui
    inputs.wiremix.packages.${pkgs.stdenv.hostPlatform.system}.wiremix

    # Hyprland utilities used by the declarative keybindings/session
    brightnessctl
    hyprpolkitagent
    playerctl
    wl-clipboard
    screenshot
    desktopFeedback

    # Command-line workflow
    fd
    jq
    ripgrep
    tree

    # Keep Codex on the fast-moving pinned nixpkgs input.
    pkgsUnstable.codex
  ];
}

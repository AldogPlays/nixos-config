{
  config,
  inputs,
  lib,
  pkgs,
  pkgsUnstable,
  desktopTheme,
  packetTracerEnable,
  ...
}:

let
  theme = desktopTheme;
  moonlight = pkgs.callPackage ../../packages/moonlight-theme.nix { inherit desktopTheme; };
  # Keep GTK file dialogs outside ONLYOFFICE's bundled toolkit process.
  onlyoffice = pkgs.onlyoffice-desktopeditors.override {
    buildFHSEnv =
      args:
      pkgs.buildFHSEnv (
        args
        // {
          # Native GTK dialogs resolve the shared UI font through /usr/share/fonts.
          targetPkgs = p: args.targetPkgs p ++ [ (lib.getAttrFromPath theme.typography.package p) ];
          runScript = "${args.runScript} --xdg-desktop-portal=default";
        }
      );
  };
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
  # Copy upstream entries so actions, MIME handlers and launch arguments survive.
  launcherEntries =
    pkgs.runCommand "launcher-entries"
      {
        nativeBuildInputs = [ pkgs.desktop-file-utils ];
      }
      ''
        mkdir -p "$out/share/applications"
        describe() {
          cp "$1/share/applications/$2.desktop" "$out/share/applications/$2.desktop"
          chmod u+w "$out/share/applications/$2.desktop"
          desktop-file-edit --set-generic-name="$3" "$out/share/applications/$2.desktop"
        }
        hide() {
          describe "$1" "$2" ""
          desktop-file-edit --set-key=NoDisplay --set-value=true "$out/share/applications/$2.desktop"
        }
        describe ${pkgs.alacritty} Alacritty 'Terminal'
        describe ${onlyoffice} onlyoffice-desktopeditors 'Document editor'
        desktop-file-edit --add-mime-type=text/rtf "$out/share/applications/onlyoffice-desktopeditors.desktop"
        describe ${pkgs.modrinth-app} 'Modrinth App' 'Minecraft mods'
        describe ${pkgsUnstable.joplin-desktop} appimagekit-joplin 'Notes'
        describe ${
          config.programs.vesktop.package.override { withSystemVencord = true; }
        } vesktop 'Discord chat'
        describe ${pkgsUnstable.chatgpt} chatgpt 'AI assistant'
        ${lib.optionalString packetTracerEnable "describe ${pkgs.cisco-packet-tracer_9} cisco-packet-tracer-9 'Network simulator'"}
        describe ${config.programs.librewolf.finalPackage} librewolf 'Web browser'
        describe ${pkgs.lutris} net.lutris.Lutris 'Game launcher'
        describe ${moonlight} com.moonlight_stream.Moonlight 'Game streaming'
        describe ${pkgs.kdePackages.dolphin} org.kde.dolphin 'Files'
        describe ${pkgs.steam} steam 'Steam games'
        describe ${pkgs.system-config-printer} system-config-printer 'Printer settings'
        describe ${pkgs.rofi} rofi-theme-selector 'Change system theme'
        desktop-file-edit --set-name='Theme Selector' "$out/share/applications/rofi-theme-selector.desktop"
        desktop-file-edit --set-key=Exec --set-value=theme-menu "$out/share/applications/rofi-theme-selector.desktop"
        desktop-file-edit --set-comment='Choose and apply a system theme.' "$out/share/applications/rofi-theme-selector.desktop"
        hide ${pkgs.kdePackages.ark} org.kde.ark
        hide ${pkgs.kdePackages.gwenview} org.kde.gwenview
        hide ${pkgs.qpdfview.override { libsForQt5 = pkgs.qt6Packages; }} qpdfview
        ${lib.optionalString packetTracerEnable "hide ${pkgs.cisco-packet-tracer_9} cisco-packet-tracer-ptsa-9"}
        hide ${pkgs.cups} cups
        hide ${pkgs.rofi} rofi
        hide ${pkgs.uwsm} uuctl
        hide ${pkgs.xterm} xterm
        hide ${inputs.wiremix.packages.${pkgs.stdenv.hostPlatform.system}.wiremix} wiremix
        desktop-file-validate "$out"/share/applications/*.desktop
      '';
in
{
  # Rofi's wrapper prepends its own share directory to XDG_DATA_DIRS. User data
  # takes precedence over that directory, so its own entries must live here.
  xdg.dataFile =
    lib.genAttrs
      [
        "applications/rofi.desktop"
        "applications/rofi-theme-selector.desktop"
      ]
      (path: {
        source = "${launcherEntries}/share/${path}";
      });

  # NoDisplay hides menus without disabling the applications' other entry points.
  xdg.desktopEntries.nixos-manual = {
    name = "NixOS Manual";
    exec = "nixos-help";
    noDisplay = true;
  };

  home.packages =
    with pkgs;
    lib.optional packetTracerEnable cisco-packet-tracer_9
    ++ [
      (lib.hiPrio launcherEntries)
      # Desktop applications
      onlyoffice
      kdePackages.dolphin
      # Expose the MTP D-Bus service and kiod plugin already in Dolphin's closure.
      kdePackages.kio-extras
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
      pkgsUnstable.joplin-desktop
      lutris
      moonlight
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
      dnsutils # dig and nslookup for DNS diagnostics
      fd
      jq
      openssl
      ripgrep
      traceroute
      tree

      # Keep Codex on the fast-moving pinned nixpkgs input.
      pkgsUnstable.codex
    ];
}

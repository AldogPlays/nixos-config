{
  lib,
  pkgs,
  desktopTheme,
  themeConfiguration,
  themeSelection,
  ...
}:

let
  theme = desktopTheme;
  inherit (theme)
    roles
    typography
    cursor
    geometry
    ;
  # Plymouth's native script plugin accepts normalized RGB channels.
  plymouthRGB =
    color:
    lib.concatMapStringsSep ", "
      (offset: toString (lib.fromHexString (builtins.substring offset 2 color) / 255.0))
      [
        1
        3
        5
      ];
  plymouthTheme =
    pkgs.runCommand "plymouth-jeffrey-theme"
      {
        nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pillow ])) ];
        script = pkgs.replaceVars ../../dotfiles/plymouth/theme.script {
          BACKGROUND = plymouthRGB roles.background;
          FOREGROUND = plymouthRGB roles.foreground;
          FONT = "${typography.family} ${toString typography.size}";
          FIELD_WIDTH = toString geometry.passwordWidth;
          FIELD_HEIGHT = toString geometry.passwordHeight;
          INSET = toString geometry.overlayInset;
          PADDING = toString geometry.padding;
        };
      }
      ''
        themeDir="$out/share/plymouth/themes/jeffrey-theme"
        mkdir -p "$themeDir"
        cp "$script" "$themeDir/theme.script"
        cat > "$themeDir/jeffrey-theme.plymouth" <<EOF
        [Plymouth Theme]
        Name=Jeffrey Theme
        Description=Shared-theme disk unlock
        ModuleName=script

        [script]
        ImageDir=$themeDir
        ScriptFile=$themeDir/theme.script
        EOF
        export themeDir
        python3 <<'PY'
        import os
        from PIL import Image, ImageDraw

        width, height = ${toString geometry.passwordWidth}, ${toString geometry.passwordHeight}
        image = Image.new("RGBA", (width, height))
        ImageDraw.Draw(image).rounded_rectangle(
            (0, 0, width - 1, height - 1), radius=${toString geometry.radius},
            fill="${roles.backgroundAlt}", outline="${roles.borderFocused}",
            width=${toString geometry.borderWidth},
        )
        image.save(os.path.join(os.environ["themeDir"], "entry.png"))
        PY
      '';
  loginTheme =
    (pkgs.where-is-my-sddm-theme.override {
      variants = [ "qt6" ];
      themeConfig.General = {
        backgroundFill = roles.background;
        basicTextColor = roles.foreground;
        passwordTextColor = roles.foreground;
        passwordInputBackground = roles.backgroundAlt;
        passwordCursorColor = roles.accent;
        passwordInputRadius = geometry.radius;
        passwordInputWidth = 0.2;
        passwordFontSize = typography.size;
        usersFontSize = typography.size;
        sessionsFontSize = typography.size;
        helpFontSize = typography.size;
        font = typography.family;
        helpFont = typography.family;
        showUsersByDefault = true;
        showSessionsByDefault = true;
        showUserRealNameByDefault = false;
        cursorBlinkAnimation = false;
        hideCursor = false;
        blurRadius = 0;
      };
    }).overrideAttrs
      (old: {
        # Upstream exposes most colors as settings, but hardcodes selection/failure.
        postInstall = (old.postInstall or "") + ''
          substituteInPlace "$out/share/sddm/themes/where_is_my_sddm_theme/Main.qml" \
            --replace-fail 'selectedTextColor: "#000000"' 'selectedTextColor: "${roles.selectionForeground}"' \
            --replace-fail 'selectionColor: textColor' 'selectionColor: "${roles.selection}"' \
            --replace-fail 'border.color: "#ff3117"' 'border.color: "${roles.error}"' \
            --replace-fail 'backgroundBorder.border.width = 5;' 'backgroundBorder.border.width = ${toString geometry.borderWidth};' \
            --replace-fail 'NumberAnimation { from: 5; to: 10; duration: 700 }' 'NumberAnimation { from: ${toString geometry.borderWidth}; to: ${toString geometry.borderWidth}; duration: 700 }' \
            --replace-fail 'NumberAnimation { from: 10; to: 5;  duration: 400 }' 'NumberAnimation { from: ${toString geometry.borderWidth}; to: ${toString geometry.borderWidth}; duration: 400 }'
        '';
      });
in
{
  imports = [ ./waydroid.nix ];

  environment.etc."desktop-theme.json".text = builtins.toJSON {
    preset = themeSelection.preset;
    inherit (theme) name;
    wallpaperMode = theme.wallpaper.mode;
    configuration = themeConfiguration;
  };
  # The NixOS module wires Plymouth into the existing initrd and password agent.
  # No initrd-style, storage, keyfile or encryption changes are needed.
  boot.plymouth = {
    enable = true;
    theme = "jeffrey-theme";
    themePackages = [ plymouthTheme ];
    font = "${lib.getAttrFromPath typography.package pkgs}/${typography.bootFontFile}";
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Supplies Steam's runtime, 32-bit graphics/audio and controller udev rules.
  programs.steam.enable = true;

  # Classify USB phones for Dolphin's existing MTP support.
  services.udev.packages = [ pkgs.libmtp ];

  # CUPS serves application print dialogs; cups-browsed creates local queues for
  # discovered network printers, including apps that cannot list temporary ones.
  services.printing = {
    enable = true;
    browsed.enable = true;
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  # Small on-demand printer/queue GUI, with the module's D-Bus/udev integration.
  programs.system-config-printer.enable = true;

  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "${loginTheme}/share/sddm/themes/where_is_my_sddm_theme";
    # Propagate the theme's Qt6 QML runtime imports into the greeter wrapper.
    extraPackages = [ loginTheme ];
    settings.Theme = {
      Font = "${typography.family},${toString typography.size},-1,5,50,0,0,0,0,0";
      CursorTheme = cursor.name;
      CursorSize = cursor.size;
    };
  };
  # Make cursor assets available to the separate greeter account as well.
  environment.systemPackages = [ (lib.getAttrFromPath cursor.package pkgs) ];

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    # Declare authentication directly: the NixOS hyprlock module also enables
    # an idle service. Keep locking manual; Home Manager supplies the locker.
    pam.services.hyprlock = { };
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  fonts.packages = with pkgs; [
    (lib.getAttrFromPath typography.package pkgs)
    (lib.getAttrFromPath typography.symbolsPackage pkgs)
    noto-fonts
    noto-fonts-color-emoji
  ];

  fonts.fontconfig.defaultFonts.monospace = [
    typography.family
    typography.symbolsFamily
  ];
}

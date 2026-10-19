{ pkgs, ... }:

let
  theme = import ../../theme;
  inherit (theme) roles typography cursor;
  loginTheme =
    (pkgs.where-is-my-sddm-theme.override {
      variants = [ "qt6" ];
      themeConfig.General = {
        backgroundFill = roles.background;
        basicTextColor = roles.foreground;
        passwordTextColor = roles.foreground;
        passwordInputBackground = roles.backgroundAlt;
        passwordCursorColor = roles.accent;
        passwordInputRadius = 4;
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
            --replace-fail 'selectedTextColor: "#000000"' 'selectedTextColor: "${roles.foreground}"' \
            --replace-fail 'selectionColor: textColor' 'selectionColor: "${roles.selection}"' \
            --replace-fail 'border.color: "#ff3117"' 'border.color: "${roles.error}"' \
            --replace-fail 'backgroundBorder.border.width = 5;' 'backgroundBorder.border.width = 1;' \
            --replace-fail 'NumberAnimation { from: 5; to: 10; duration: 700 }' 'NumberAnimation { from: 1; to: 1; duration: 700 }' \
            --replace-fail 'NumberAnimation { from: 10; to: 5;  duration: 400 }' 'NumberAnimation { from: 1; to: 1; duration: 400 }'
        '';
      });
in
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Supplies Steam's runtime, 32-bit graphics/audio and controller udev rules.
  programs.steam.enable = true;

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
  environment.systemPackages = [ pkgs.catppuccin-cursors.mochaDark ];

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    # Declare authentication directly: the NixOS hyprlock module also enables
    # an idle service, which is not requested. Home Manager supplies the locker.
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
    monaspace.static
    nerd-fonts.symbols-only
    noto-fonts
    noto-fonts-color-emoji
  ];

  fonts.fontconfig.defaultFonts.monospace = [
    "Monaspace Neon"
    "Symbols Nerd Font Mono"
  ];
}

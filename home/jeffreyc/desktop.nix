{
  config,
  lib,
  pkgs,
  ...
}:

let
  theme = import ../../theme;
  inherit (theme) roles palette typography;
  fontSize = toString typography.size;
  wallpaperInterval = 15 * 60;
  wallpaperPython = pkgs.python3.withPackages (p: [ p.pillow ]);
  workspaceWallpapers = pkgs.writeShellScript "workspace-wallpapers" ''
    exec ${wallpaperPython}/bin/python3 ${../../dotfiles/hypr/workspace-wallpapers.py} \
      --directory ${lib.escapeShellArg "${config.xdg.userDirs.pictures}/Wallpapers"} \
      --hyprctl ${pkgs.hyprland}/bin/hyprctl --awww ${pkgs.awww}/bin/awww \
      --interval ${toString wallpaperInterval} "$@"
  '';
  kdeFont = "${typography.family},${fontSize},-1,5,50,0,0,0,0,0";
  # Native Adwaita/adw-gtk3 semantic colors; both GTK generations consume these.
  gtkColors = {
    accent_color = roles.accent;
    accent_bg_color = roles.accent;
    accent_fg_color = roles.background;
    destructive_color = roles.error;
    destructive_bg_color = roles.error;
    destructive_fg_color = roles.background;
    success_color = roles.success;
    success_bg_color = roles.success;
    success_fg_color = roles.background;
    warning_color = roles.foreground;
    warning_bg_color = roles.warning;
    warning_fg_color = roles.foreground;
    error_color = roles.error;
    error_bg_color = roles.error;
    error_fg_color = roles.background;
    window_bg_color = roles.background;
    window_fg_color = roles.foreground;
    view_bg_color = roles.background;
    view_fg_color = roles.foreground;
    headerbar_bg_color = roles.backgroundAlt;
    headerbar_fg_color = roles.foreground;
    headerbar_backdrop_color = roles.backgroundAlt;
    headerbar_border_color = roles.border;
    headerbar_shade_color = "transparent";
    headerbar_darker_shade_color = "transparent";
    sidebar_bg_color = roles.backgroundAlt;
    sidebar_fg_color = roles.foreground;
    sidebar_backdrop_color = roles.backgroundAlt;
    sidebar_border_color = roles.border;
    sidebar_shade_color = "transparent";
    secondary_sidebar_bg_color = roles.backgroundAlt;
    secondary_sidebar_fg_color = roles.foreground;
    secondary_sidebar_backdrop_color = roles.backgroundAlt;
    secondary_sidebar_border_color = roles.border;
    secondary_sidebar_shade_color = "transparent";
    card_bg_color = roles.surface;
    card_fg_color = roles.foreground;
    card_shade_color = "transparent";
    dialog_bg_color = roles.background;
    dialog_fg_color = roles.foreground;
    popover_bg_color = roles.backgroundAlt;
    popover_fg_color = roles.foreground;
    popover_shade_color = "transparent";
    thumbnail_bg_color = roles.surface;
    thumbnail_fg_color = roles.foreground;
    shade_color = "transparent";
    scrollbar_outline_color = roles.background;
    borders = roles.border;
    theme_bg_color = roles.background;
    theme_fg_color = roles.foreground;
    theme_base_color = roles.background;
    theme_text_color = roles.foreground;
    theme_selected_bg_color = roles.selection;
    theme_selected_fg_color = roles.foreground;
    theme_unfocused_bg_color = roles.background;
    theme_unfocused_fg_color = roles.foreground;
    theme_unfocused_base_color = roles.background;
    theme_unfocused_text_color = roles.foreground;
    theme_unfocused_selected_bg_color = roles.selection;
    theme_unfocused_selected_fg_color = roles.foreground;
  };
  gtkNamedColors = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "@define-color ${name} ${value};") gtkColors
  );
  hex = lib.removePrefix "#";
  rgb =
    color:
    lib.concatMapStringsSep ", "
      (offset: toString (lib.fromHexString (builtins.substring offset 2 (hex color))))
      [
        0
        2
        4
      ];
  glass = color: "rgba(${rgb color}, ${toString theme.material.opacity})";
  # KDE uses comma-separated RGB values, not the canonical #rrggbb notation.
  kdeForegrounds = {
    DecorationFocus = rgb roles.borderFocused;
    DecorationHover = rgb roles.border;
    ForegroundNormal = rgb roles.foreground;
    ForegroundInactive = rgb roles.foregroundMuted;
    ForegroundActive = rgb roles.accent;
    ForegroundLink = rgb roles.accent;
    ForegroundVisited = rgb palette.mauve;
    ForegroundNegative = rgb roles.error;
    ForegroundNeutral = rgb roles.foregroundMuted;
    ForegroundPositive = rgb roles.success;
  };
  kdeScheme =
    lib.mapAttrs
      (
        _: background:
        kdeForegrounds
        // {
          BackgroundNormal = rgb background;
          BackgroundAlternate = rgb roles.backgroundAlt;
        }
      )
      {
        "Colors:View" = roles.background;
        "Colors:Window" = roles.backgroundAlt;
        "Colors:Button" = roles.surface;
        "Colors:Tooltip" = roles.background;
        "Colors:Complementary" = roles.backgroundAlt;
        "Colors:Header" = roles.backgroundAlt;
      }
    // {
      "Colors:Selection" =
        kdeForegrounds
        // (lib.genAttrs [
          "ForegroundNormal"
          "ForegroundInactive"
          "ForegroundActive"
          "ForegroundLink"
          "ForegroundVisited"
          "ForegroundNegative"
          "ForegroundNeutral"
          "ForegroundPositive"
        ] (_: rgb roles.foreground))
        // {
          BackgroundNormal = rgb roles.selection;
          BackgroundAlternate = rgb roles.selection;
        };
      "ColorEffects:Inactive".Enable = false;
      General = {
        Name = "Jeffrey Latte";
        ColorScheme = "JeffreyLatte";
        shadeSortColumn = false;
      };
    };
in
{
  gtk = {
    enable = true;
    colorScheme = "light";
    gtk3 = {
      theme = {
        name = "adw-gtk3";
        package = pkgs.adw-gtk3;
      };
      extraCss = gtkNamedColors;
    };
    # Keep GTK4/libadwaita's native layout; override colors, not a GTK3 stylesheet.
    gtk4.extraCss = gtkNamedColors + ''
      :root {
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: value: "--${lib.replaceStrings [ "_" ] [ "-" ] name}: ${value};"
          ) gtkColors
        )}
        --border-color: ${roles.border};
        --window-radius: 4px;
      }
    '';
    font = {
      name = typography.family;
      size = typography.size;
    };
  };
  home.pointerCursor = {
    package = pkgs.catppuccin-cursors.mochaDark;
    inherit (theme.cursor) name size;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };
      animations.enabled = false;
      background = [
        {
          monitor = "";
          color = "rgb(${hex roles.background})";
        }
      ];
      label = [
        {
          monitor = "";
          text = "$USER";
          color = "rgb(${hex roles.foreground})";
          font_family = typography.family;
          font_size = typography.size;
          position = "0, 50";
          halign = "center";
          valign = "center";
        }
      ];
      input-field = [
        {
          monitor = "";
          size = "280, 40";
          position = "0, 0";
          halign = "center";
          valign = "center";
          outline_thickness = 1;
          rounding = 4;
          inner_color = "rgb(${hex roles.backgroundAlt})";
          outer_color = "rgb(${hex roles.borderFocused})";
          font_color = "rgb(${hex roles.foreground})";
          check_color = "rgb(${hex roles.accent})";
          fail_color = "rgb(${hex roles.error})";
          capslock_color = "rgb(${hex roles.warning})";
          swap_font_color = false;
          font_family = typography.family;
          placeholder_text = "Password";
          fail_text = "Authentication failed";
          fade_on_empty = false;
          dots_center = true;
          shadow_passes = 0;
        }
      ];
    };
  };
  xdg.configFile."kcminputrc".source = (pkgs.formats.ini { }).generate "kcminputrc" {
    Mouse = {
      cursorTheme = config.home.pointerCursor.name;
      cursorSize = config.home.pointerCursor.size;
    };
  };
  qt = {
    enable = true;
    platformTheme = {
      name = "kde";
      # Avoid the module's larger KDE default package set (including System Settings).
      package = pkgs.kdePackages.plasma-integration;
    };
    style = {
      name = "Breeze";
      package = pkgs.kdePackages.breeze;
    };
  };
  # Expose the icon theme already in Dolphin's closure to the user's Qt apps.
  home.packages = [ pkgs.kdePackages.breeze-icons ];
  xdg.dataFile."color-schemes/JeffreyLatte.colors".source =
    (pkgs.formats.ini { }).generate "JeffreyLatte.colors"
      kdeScheme;
  xdg.configFile."kdeglobals".source = (pkgs.formats.ini { }).generate "kdeglobals" (
    kdeScheme
    // {
      General = kdeScheme.General // {
        font = kdeFont;
        fixed = kdeFont;
        menuFont = kdeFont;
        toolBarFont = kdeFont;
        smallestReadableFont = kdeFont;
        taskbarFont = kdeFont;
        TerminalApplication = "alacritty";
        TerminalService = "Alacritty.desktop";
        BrowserApplication = "librewolf.desktop";
      };
      Icons.Theme = "breeze";
      KDE.widgetStyle = "Breeze";
    }
  );

  # Translate canonical colors only at the application's format boundary.
  xdg.configFile."hypr/hyprland.lua".source = pkgs.writeText "hyprland.lua" (
    builtins.replaceStrings
      [
        "@THEME_ACTIVE_BORDER@"
        "@THEME_INACTIVE_BORDER@"
        "@THEME_SHADOW@"
        "@CURSOR_THEME@"
        "@CURSOR_SIZE@"
        "@BLUR_SIZE@"
        "@BLUR_PASSES@"
        "@BLUR_NOISE@"
        "@BLUR_CONTRAST@"
        "@BLUR_BRIGHTNESS@"
        "@BLUR_VIBRANCY@"
        "@FOCUSED_OPACITY@"
        "@UNFOCUSED_OPACITY@"
        "@WAYBAR_SYSTEMCTL@"
        "@WORKSPACE_WALLPAPERS@"
        "@WALLPAPER_INTERVAL@"
        "@WALLPAPER_AWWW@"
        "@THEME_BACKGROUND@"
      ]
      [
        (hex roles.borderFocused)
        (hex roles.border)
        (hex roles.backgroundAlt)
        config.home.pointerCursor.name
        (toString config.home.pointerCursor.size)
        (toString theme.material.blur.size)
        (toString theme.material.blur.passes)
        (toString theme.material.blur.noise)
        (toString theme.material.blur.contrast)
        (toString theme.material.blur.brightness)
        (toString theme.material.blur.vibrancy)
        (toString theme.material.focusedOpacity)
        (toString theme.material.opacity)
        "${pkgs.systemd}/bin/systemctl"
        "${workspaceWallpapers}"
        (toString wallpaperInterval)
        "${pkgs.awww}/bin/awww"
        (hex roles.background)
      ]
      (builtins.readFile ../../dotfiles/hypr/hyprland.lua)
  );

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 24;
      margin-top = 4;
      margin-left = 4;
      margin-right = 4;
      spacing = 4;
      # Hyprland's native event callbacks reconcile this with tiles/Rofi.
      on-sigusr1 = "toggle";
      # Keep invisible mode observable by Lua even though its surface stays mapped.
      modes.invisible = {
        layer = "bottom";
        exclusive = false;
        passthrough = true;
        visible = false;
      };
      modules-left = [
        "hyprland/workspaces"
        "hyprland/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "network"
        "bluetooth"
        "pulseaudio"
        "battery"
        "custom/notifications"
        "tray"
      ];
      clock.format = "{:%a %b %d  %H:%M}";
      network = {
        format-wifi = "{essid}  {signalStrength}%";
        format-ethernet = "Ethernet";
        format-disconnected = "Offline";
        tooltip-format = "{ifname}: {ipaddr}/{cidr}";
        on-click = "alacritty --class wlctl -e wlctl";
      };
      bluetooth = {
        format = "BT {status}";
        format-connected = "BT {num_connections}";
        on-click = "alacritty --class bluetui -e bluetui";
      };
      pulseaudio = {
        format = "{volume}% {icon}";
        format-muted = "Muted";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = "alacritty --class wiremix -e wiremix";
      };
      battery = {
        format = "{capacity}% {icon}";
        format-charging = "{capacity}% ";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
        ];
      };
      "custom/notifications" = {
        exec = "${pkgs.swaynotificationcenter}/bin/swaync-client -swb";
        return-type = "json";
        format = "{icon}";
        format-icons = {
          notification = "";
          none = "";
          dnd-notification = "";
          dnd-none = "";
          inhibited-notification = "";
          inhibited-none = "";
          dnd-inhibited-notification = "";
          dnd-inhibited-none = "";
        };
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        tooltip = false;
      };
    };
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "${typography.family}", "Symbols Nerd Font";
        font-size: ${fontSize}pt;
      }
      window#waybar { background: ${roles.background}; color: ${roles.foreground}; border: 1px solid ${roles.border}; border-radius: 4px; }
      #workspaces { background: transparent; }
      #workspaces button { padding: 0 5px; border-radius: 4px; color: ${roles.foregroundMuted}; background: transparent; box-shadow: none; text-shadow: none; }
      #workspaces button:hover { background: ${roles.surface}; color: ${roles.foreground}; }
      #workspaces button.active { color: ${roles.accent}; background: ${roles.backgroundAlt}; }
      #workspaces button.urgent { color: ${roles.error}; }
      tooltip { background: ${roles.backgroundAlt}; border: 1px solid ${roles.border}; }
      tooltip label { color: ${roles.foreground}; }
      #battery.warning { color: ${roles.foreground}; border-bottom: 1px solid ${roles.warning}; }
      #battery.critical, #network.disconnected { color: ${roles.error}; }
      #clock, #network, #bluetooth, #pulseaudio, #battery, #custom-notifications, #tray { padding: 0 5px; }
    '';
  };

  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      timeout = 5;
      widgets = [
        "title"
        "dnd"
        "notifications"
      ];
    };
    style = ''
      /* SwayNC 0.12 uses GTK4 custom properties; its default CSS supplies layout. */
      :root {
        --cc-bg: ${glass roles.backgroundAlt};
        --noti-border-color: ${roles.border};
        --noti-bg: ${rgb roles.background};
        --noti-bg-alpha: ${toString theme.material.opacity};
        --noti-bg-darker: ${roles.backgroundAlt};
        --noti-bg-hover: ${roles.surface};
        --noti-bg-focus: ${roles.selection};
        --noti-close-bg: ${roles.surface};
        --noti-close-bg-hover: ${roles.selection};
        --text-color: ${roles.foreground};
        --text-color-disabled: ${roles.foregroundMuted};
        --bg-selected: ${roles.accent};
        --border-radius: 4px;
        --notification-shadow: none;
        --font-size-body: ${fontSize}pt;
        --font-size-summary: ${fontSize}pt;
      }
      * { font-family: "${typography.family}", "Symbols Nerd Font"; font-size: ${fontSize}pt; }
      .widget-title > label, .widget-dnd > label { font-size: ${fontSize}pt; }
      .notification-row .notification-background .notification.critical { border-color: ${roles.error}; }
      .control-center { border: none; }
      .widget-title > button, .notification-action, .widget-dnd switch {
        background: ${roles.surface}; color: ${roles.foreground};
        border: 1px solid ${roles.border}; box-shadow: none;
      }
      .widget-title > button:hover, .notification-action:hover { background: ${roles.selection}; }
      .widget-dnd switch:checked { background: ${roles.accent}; }
      .widget-dnd switch slider { background: ${roles.background}; box-shadow: none; }
    '';
  };

  services.awww = {
    enable = true;
    # Our controller restores assignments; do not restore a separate native cache.
    extraArgs = [ "--no-cache" ];
  };

  systemd.user.services = {
    # Restore the visible workspaces after backend startup/restart, without polling.
    awww.Service.ExecStartPost = "${workspaceWallpapers} --wait";

    hyprpolkitagent = {
      Unit = {
        Description = "Hyprland PolicyKit authentication agent";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}

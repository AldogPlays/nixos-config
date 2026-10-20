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
  wallpaperCacheMiB = 512;
  hyprmosaic = pkgs.callPackage ../../packages/hyprmosaic { };
  wallpaperPython = pkgs.python3.withPackages (p: [ p.pillow ]);
  workspaceWallpapers = pkgs.writeShellScript "workspace-wallpapers" ''
    exec ${wallpaperPython}/bin/python3 ${../../dotfiles/hypr/workspace-wallpapers.py} \
      --directory ${lib.escapeShellArg "${config.xdg.userDirs.pictures}/Wallpapers"} \
      --hyprctl ${pkgs.hyprland}/bin/hyprctl \
      --cache-directory ${lib.escapeShellArg "${config.xdg.cacheHome}/workspace-wallpapers"} \
      --cache-limit ${toString (wallpaperCacheMiB * 1024 * 1024)} \
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
        "@HYPRMOSAIC_PLUGIN@"
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
        (toString theme.material.unfocusedOpacity)
        "${pkgs.systemd}/bin/systemctl"
        "${workspaceWallpapers}"
        (toString wallpaperInterval)
        "${hyprmosaic}/lib/libhyprmosaic.so"
        (hex roles.background)
      ]
      (builtins.readFile ../../dotfiles/hypr/hyprland.lua)
  );

  programs.waybar = {
    enable = true;
    package = pkgs.callPackage ../../packages/waybar-tray { };
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
      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [
        "group/app-tray"
        "network"
        "bluetooth"
        "pulseaudio"
        "power-profiles-daemon"
        "battery"
        "custom/notifications"
      ];
      tray = {
        icon-size = 18;
        spacing = 8;
      };
      "group/app-tray" = {
        orientation = "horizontal";
        drawer = {
          signal = 8;
          transition-duration = 160;
          transition-left-to-right = false;
        };
        modules = [ "tray" ];
      };
      clock = {
        format = "{:%a %b %d  %I:%M %p}";
        tooltip = false;
      };
      network = {
        format-wifi = ''<span foreground="${roles.network}"></span>'';
        format-ethernet = ''<span foreground="${roles.network}">󰈀</span>'';
        format-linked = "󰈀";
        format-disconnected = "󰖪";
        format-disabled = "󰖪";
        tooltip-format-wifi = "{essid}\nSignal: {signalStrength}%\n{ipaddr}\nClick for network controls";
        tooltip-format-ethernet = "Wired connection\n{ipaddr}\nClick for network controls";
        tooltip-format-disconnected = "No network connection\nClick for network controls";
        tooltip-format-disabled = "Wi-Fi disabled\nClick for network controls";
        on-click = ''alacritty --class wlctl -o 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' -e wlctl'';
      };
      bluetooth = {
        format = ''<span foreground="${roles.bluetooth}"></span>'';
        format-disabled = "";
        format-off = "";
        format-connected = ''<span foreground="${roles.bluetooth}"></span> {num_connections}'';
        tooltip-format = "Bluetooth: {status}\nClick for Bluetooth controls";
        tooltip-format-connected = "{device_enumerate}\nClick for Bluetooth controls";
        tooltip-format-enumerate-connected = "{device_alias}";
        on-click = ''alacritty --class bluetui -o 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' -e bluetui'';
      };
      pulseaudio = {
        format = ''<span foreground="${roles.audio}">{icon}</span> {volume}%'';
        format-muted = "󰝟";
        format-bluetooth = ''<span foreground="${roles.audio}">󰂰</span> {volume}%'';
        format-bluetooth-muted = "󰝟";
        tooltip-format = "{desc}\nClick for audio controls · Scroll for volume";
        scroll-step = 5;
        max-volume = 100;
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = ''alacritty --class wiremix -o 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' -e wiremix'';
      };
      "power-profiles-daemon" = {
        format = "{icon}";
        format-icons = {
          default = "";
          performance = "";
          balanced = "";
          power-saver = "";
        };
        tooltip-format = "Power mode: {profile}\nClick to cycle modes\nPlugging in or unplugging restores automatic selection";
      };
      battery = {
        states = {
          warning = 20;
          critical = 10;
        };
        format = "{icon}";
        format-charging = "󰂄";
        format-plugged = "󰂄";
        format-full = "";
        tooltip-format = "Battery: {capacity}%\n{timeTo}";
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
          notification = "";
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
      tooltip { background: ${roles.background}; border: 1px solid ${roles.border}; border-radius: 4px; }
      tooltip label { color: ${roles.foreground}; padding: 6px; font-family: "${typography.family}", monospace; text-shadow: none; }
      /* Flat controls with a hover cue; avoid a row of tiny input-like boxes. */
      #network, #bluetooth, #pulseaudio, #power-profiles-daemon, #custom-notifications {
        background: transparent; border: none;
        border-radius: 4px; margin: 2px 1px; padding: 0 7px;
      }
      #network:hover, #bluetooth:hover, #pulseaudio:hover, #power-profiles-daemon:hover, #custom-notifications:hover {
        background: ${roles.surface};
      }
      #bluetooth, #power-profiles-daemon, #custom-notifications { min-width: 16px; }
      #bluetooth.off, #bluetooth.disabled, #pulseaudio.muted { color: ${roles.foregroundMuted}; }
      #power-profiles-daemon.performance { color: ${roles.powerPerformance}; }
      #power-profiles-daemon.balanced { color: ${roles.powerBalanced}; }
      #power-profiles-daemon.power-saver { color: ${roles.powerSaver}; }
      #custom-notifications { color: ${roles.notifications}; }
      #app-tray { margin-right: 5px; }
      #app-tray-arrow { padding: 0 7px; color: ${roles.foregroundMuted}; -gtk-icon-transform: rotate(0deg); transition: -gtk-icon-transform 160ms ease; }
      #app-tray.open #app-tray-arrow { color: ${roles.accent}; -gtk-icon-transform: rotate(180deg); }
      #tray { padding: 0 5px; }
      #battery { padding: 0 6px; margin-left: 3px; }
      #battery.warning { color: ${roles.foreground}; border-bottom: 1px solid ${roles.warning}; }
      #battery.critical, #network.disconnected { color: ${roles.error}; }
      #battery.charging, #battery.plugged, #battery.full { color: ${roles.success}; }
      #clock { padding: 0 6px; }
    '';
  };

  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      control-center-width = 400;
      notification-window-width = 400;
      # Inset overlays farther than the tiled-window gaps so edges do not merge.
      control-center-margin-top = 12;
      control-center-margin-right = 12;
      control-center-margin-bottom = 12;
      fit-to-screen = false;
      control-center-height = -1;
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
        --cc-bg: ${roles.background};
        --noti-border-color: ${roles.border};
        --noti-bg: ${rgb roles.background};
        --noti-bg-alpha: 1;
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
        --notification-icon-size: 32px;
        --notification-app-icon-size: 16px;
        --notification-group-icon-size: 20px;
        --font-size-body: ${fontSize}pt;
        --font-size-summary: ${fontSize}pt;
      }
      * {
        font-family: "${typography.family}", "Symbols Nerd Font";
        font-size: ${fontSize}pt;
        text-shadow: none;
        -gtk-icon-shadow: none;
      }
      .control-center { border: 1px solid ${roles.borderFocused}; padding: 4px; }
      .widget { margin: 0; padding: 4px; }
      .widget-title > label, .widget-dnd > label { font-size: ${fontSize}pt; }
      .widget-title > label { font-weight: bold; }
      .widget-dnd { margin-bottom: 4px; }
      .control-center button, .notification button, .close-button {
        background-image: none;
        background-color: transparent;
        color: ${roles.foreground};
        border: none;
        border-radius: 4px;
        box-shadow: none;
        min-height: 24px;
        padding: 2px 6px;
      }
      .notification-group, .notification-row:focus, .notification-group:focus { background: transparent; }
      .notification-row .notification-background { padding: 2px 4px; }
      /* Match the panel's inset; layer-shell already respects Waybar's space. */
      .floating-notifications { padding: 12px; }
      .floating-notifications .notification-row .notification-background { padding: 0; margin-bottom: 4px; }
      .notification-row .notification-background .notification .notification-default-action { padding: 6px; }
      .control-center .notification-group .notification { background: ${roles.background}; }
      .notification-group .notification-group-buttons, .notification-group .notification-group-headers { margin: 2px 4px; }
      .notification-group .notification-group-close-button .close-button { margin: 4px 8px; }
      .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .time {
        color: ${roles.foregroundMuted}; font-weight: normal;
      }
      .notification-row .notification-background .notification .notification-default-action .notification-content .app-icon { -gtk-icon-shadow: none; }
      .notification-row .notification-background .notification.critical { border-color: ${roles.error}; }
      .widget-title > button, .notification .notification-action > button, .widget-dnd switch, .close-button {
        background: ${roles.surface}; color: ${roles.foreground};
        border: 1px solid ${roles.border}; border-radius: 4px; box-shadow: none;
      }
      .widget-title > button:hover, .notification .notification-action > button:hover, .close-button:hover { background: ${roles.selection}; }
      /* GTK dims disabled labels as well as recoloring them. Keep Clear All
         readable when the list is empty, while retaining its disabled state. */
      .widget-title > button, .widget-title > button label { opacity: 1; filter: none; }
      .widget-title > button label { color: inherit; }
      .widget-title > button:disabled { background: ${roles.backgroundAlt}; color: ${roles.foregroundMuted}; }
      .control-center button:focus-visible, .notification button:focus-visible { outline: 1px solid ${roles.borderFocused}; outline-offset: -1px; }
      .notification-row .notification-background .notification .notification-action { margin: 0 2px; }
      .close-button { min-width: 20px; min-height: 20px; padding: 0; margin-top: 4px; margin-right: 6px; }
      .widget-dnd switch { min-height: 20px; }
      .widget-dnd switch:checked { background: ${roles.accent}; }
      .widget-dnd switch slider { background: ${roles.background}; border-radius: 3px; box-shadow: none; min-width: 16px; min-height: 16px; }
    '';
  };

  systemd.user.services = {
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

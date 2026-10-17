{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  theme = import ../../theme;
  inherit (theme) roles palette typography;
  fontSize = toString typography.size;
  kdeFont = "${typography.family},${fontSize},-1,5,50,0,0,0,0,0";
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
  # Keep nixpkgs' Hyprland/compiler pairing, with upstream's compatible Lua source.
  hyprspace = pkgs.hyprlandPlugins.hyprspace.overrideAttrs (_: {
    src = inputs.hyprspace-src;
    version = "0-unstable-${inputs.hyprspace-src.shortRev}";
  });
in
{
  gtk = {
    enable = true;
    font = {
      name = typography.family;
      size = typography.size;
    };
  };
  home.pointerCursor = {
    package = pkgs.catppuccin-cursors.mochaDark;
    name = "catppuccin-mocha-dark-cursors";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
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
        "@HYPRSPACE_PLUGIN@"
        "@THEME_ACTIVE_BORDER@"
        "@THEME_INACTIVE_BORDER@"
        "@THEME_SHADOW@"
        "@CURSOR_THEME@"
        "@CURSOR_SIZE@"
      ]
      [
        "${hyprspace}/lib/libhyprspace.so"
        (hex roles.borderFocused)
        (hex roles.border)
        (hex roles.backgroundAlt)
        config.home.pointerCursor.name
        (toString config.home.pointerCursor.size)
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
      spacing = 4;
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
      window#waybar { background: ${roles.background}; color: ${roles.foreground}; }
      #workspaces button { padding: 0 5px; color: ${roles.foregroundMuted}; background: transparent; box-shadow: none; text-shadow: none; }
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
        --cc-bg: ${roles.backgroundAlt};
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
        --font-size-body: ${fontSize}pt;
        --font-size-summary: ${fontSize}pt;
      }
      * { font-family: "${typography.family}", "Symbols Nerd Font"; font-size: ${fontSize}pt; }
      .widget-title > label, .widget-dnd > label { font-size: ${fontSize}pt; }
      .notification-row .notification-background .notification.critical { border-color: ${roles.error}; }
      .control-center { border: 1px solid ${roles.border}; }
      .widget-title > button, .notification-action, .widget-dnd switch {
        background: ${roles.surface}; color: ${roles.foreground};
        border: 1px solid ${roles.border}; box-shadow: none;
      }
      .widget-title > button:hover, .notification-action:hover { background: ${roles.selection}; }
      .widget-dnd switch:checked { background: ${roles.accent}; }
      .widget-dnd switch slider { background: ${roles.background}; box-shadow: none; }
    '';
  };

  services.wpaperd = {
    enable = true;
    settings.default = {
      path = "${config.xdg.userDirs.pictures}/Wallpapers";
      sorting = "random";
      duration = "15m";
      recursive = true;
      mode = "center";
      transition-time = 0;
    };
  };

  systemd.user.services = {
    # This Home Manager release writes wallpaper.toml; wpaperd defaults to config.toml.
    wpaperd.Service.ExecStart = lib.mkForce (
      "${pkgs.wpaperd}/bin/wpaperd --config ${config.xdg.configHome}/wpaperd/wallpaper.toml"
    );

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

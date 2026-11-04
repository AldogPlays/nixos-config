{
  config,
  lib,
  pkgs,
  desktopTheme,
  themeConfiguration,
  monitorConfiguration ? null,
  ...
}:

let
  theme = desktopTheme;
  inherit (theme)
    roles
    typography
    geometry
    ;
  px = value: "${toString value}px";
  fontSize = toString typography.size;
  wallpaperInterval = 15 * 60;
  wallpaperCacheMiB = 512;
  hyprmosaic = pkgs.callPackage ../../packages/hyprmosaic { };
  fullEdges = pkgs.callPackage ../../packages/hyprland-full-edges { };
  wallpaperPython = pkgs.python3.withPackages (p: [ p.pillow ]);
  themeMenuConfig = pkgs.writeText "theme-menu.json" (
    builtins.toJSON {
      configuration = themeConfiguration;
      defaultSelection = import ../../theme/selection.nix;
      presets = builtins.mapAttrs (_: preset: { inherit (preset) name; }) (
        import ../../theme/presets.nix
      );
    }
  );
  themeMenu = pkgs.writeShellApplication {
    name = "theme-menu";
    runtimeInputs = [
      pkgs.python3
      pkgs.rofi
      pkgs.alacritty
      pkgs.nix
      pkgs.nixos-rebuild
      pkgs.coreutils
    ];
    text = ''
      exec python3 ${../../scripts/theme-menu.py} --config ${themeMenuConfig} "$@"
    '';
  };
  workspaceWallpapers = pkgs.writeShellScript "workspace-wallpapers" ''
    exec ${wallpaperPython}/bin/python3 ${../../dotfiles/hypr/workspace-wallpapers.py} \
      --directory ${lib.escapeShellArg "${config.xdg.userDirs.pictures}/Wallpapers"} \
      --hyprctl ${pkgs.hyprland}/bin/hyprctl \
      --cache-directory ${lib.escapeShellArg "${config.xdg.cacheHome}/workspace-wallpapers"} \
      --cache-limit ${toString (wallpaperCacheMiB * 1024 * 1024)} \
      --color-mode ${lib.escapeShellArg theme.wallpaper.mode} \
      --interval ${toString wallpaperInterval} "$@"
  '';
  kdeFont = "${typography.family},${fontSize},-1,5,50,0,0,0,0,0";
  # Native Adwaita/adw-gtk3 semantic colors; both GTK generations consume these.
  gtkColors = {
    accent_color = roles.accent;
    accent_bg_color = roles.accent;
    accent_fg_color = roles.onAccent;
    destructive_color = roles.error;
    destructive_bg_color = roles.error;
    destructive_fg_color = roles.onError;
    success_color = roles.success;
    success_bg_color = roles.success;
    success_fg_color = roles.onSuccess;
    warning_color = roles.foreground;
    warning_bg_color = roles.warning;
    warning_fg_color = roles.onWarning;
    error_color = roles.error;
    error_bg_color = roles.error;
    error_fg_color = roles.onError;
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
    theme_selected_fg_color = roles.selectionForeground;
    theme_unfocused_bg_color = roles.background;
    theme_unfocused_fg_color = roles.foreground;
    theme_unfocused_base_color = roles.background;
    theme_unfocused_text_color = roles.foreground;
    theme_unfocused_selected_bg_color = roles.selection;
    theme_unfocused_selected_fg_color = roles.selectionForeground;
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
    ForegroundVisited = rgb roles.linkVisited;
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
        ] (_: rgb roles.selectionForeground))
        // {
          BackgroundNormal = rgb roles.selection;
          BackgroundAlternate = rgb roles.selection;
        };
      "ColorEffects:Inactive".Enable = false;
      General = {
        Name = "Jeffrey Theme";
        ColorScheme = "JeffreyTheme";
        shadeSortColumn = false;
      };
    };
in
{
  gtk = {
    enable = true;
    colorScheme = theme.appearance;
    gtk3 = {
      theme = {
        name = "adw-gtk3" + lib.optionalString (theme.appearance == "dark") "-dark";
        package = pkgs.adw-gtk3;
      };
      extraCss = gtkNamedColors;
    };
    # This pinned HM release writes a numeric enum that GTK's INI parser rejects.
    gtk4.extraConfig.gtk-interface-color-scheme = theme.appearance;
    # Keep GTK4/libadwaita's native layout; override colors, not a GTK3 stylesheet.
    gtk4.extraCss = gtkNamedColors + ''
      :root {
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: value: "--${lib.replaceStrings [ "_" ] [ "-" ] name}: ${value};"
          ) gtkColors
        )}
        --border-color: ${roles.border};
        --window-radius: ${px geometry.radius};
      }
    '';
    font = {
      name = typography.family;
      size = typography.size;
    };
  };
  home.pointerCursor = {
    package = lib.getAttrFromPath theme.cursor.package pkgs;
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
          size = "${toString geometry.passwordWidth}, ${toString geometry.passwordHeight}";
          position = "0, 0";
          halign = "center";
          valign = "center";
          outline_thickness = geometry.borderWidth;
          rounding = geometry.radius;
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
  home.packages = [
    themeMenu
    (lib.getAttrFromPath theme.icons.qt.package pkgs)
    # GTK's default symbolic icons, used by the OSD and notification controls.
    (lib.getAttrFromPath theme.icons.gtk.package pkgs)
  ];
  xdg.dataFile."color-schemes/JeffreyTheme.colors".source =
    (pkgs.formats.ini { }).generate "JeffreyTheme.colors"
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
      Icons.Theme = theme.icons.qt.name;
      KDE.widgetStyle = "Breeze";
    }
  );

  # Change only startup preferences; keep the rest of Dolphin's writable state.
  home.activation.dolphinStartup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dolphinrc=${lib.escapeShellArg "${config.xdg.configHome}/dolphinrc"}
    if [[ -f "$dolphinrc" && ! -e "$dolphinrc.before-startup-policy" ]]; then
      run cp -p "$dolphinrc" "$dolphinrc.before-startup-policy"
    fi
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$dolphinrc" \
      --group General --key RememberOpenedTabs --type bool false
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$dolphinrc" \
      --group General --key HomeUrl ${lib.escapeShellArg config.home.homeDirectory}
  '';

  # Translate canonical colors only at the application's format boundary.
  xdg.configFile."hypr/hyprland.lua".source = pkgs.writeText "hyprland.lua" (
    builtins.replaceStrings
      [
        "@BORDER_WIDTH@"
        "@CORNER_RADIUS@"
        "@SHELL_SPACING@"
        "@THEME_ACTIVE_BORDER@"
        "@THEME_INACTIVE_BORDER@"
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
        "@MONITOR_CONFIGURATION@"
        "@WORKSPACE_GROUPS@"
        "@FULL_EDGES_PLUGIN@"
      ]
      [
        (toString geometry.borderWidth)
        (toString geometry.radius)
        (toString geometry.spacing)
        (hex roles.borderFocused)
        (hex roles.border)
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
        (
          if monitorConfiguration == null then
            "{}"
          else
            "(function()\n${builtins.readFile monitorConfiguration}\nend)()"
        )
        "${../../dotfiles/hypr/workspace-groups.lua}"
        "${fullEdges}/lib/libfull-edges.so"
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
      # Visible desktop buttons must receive mouse clicks after hidden mode.
      passthrough = false;
      height = geometry.controlHeight;
      margin-top = geometry.spacing;
      margin-left = geometry.spacing;
      margin-right = geometry.spacing;
      spacing = geometry.spacing;
      # The local Waybar extension consumes explicit per-output visibility.
      visibility-signal = 10;
      # Keep invisible mode observable by Lua even though its surface stays mapped.
      modes.invisible = {
        layer = "bottom";
        exclusive = false;
        passthrough = true;
        visible = false;
      };
      modules-left = [ "hyprland/workspaces" ];
      "hyprland/workspaces" = {
        all-outputs = false;
        lua-dispatch = true;
        workspace-group-size = 10;
        hide-empty-groups = true;
        format = "{icon}";
        format-icons = builtins.listToAttrs (
          builtins.genList (index: {
            name = toString (index + 1);
            value = toString (lib.mod index 10 + 1);
          }) 100
        );
        on-scroll-up = ''hyprctl dispatch 'hl.dsp.focus({ workspace = "m-1" })' '';
        on-scroll-down = ''hyprctl dispatch 'hl.dsp.focus({ workspace = "m+1" })' '';
      };
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
        icon-size = geometry.iconSize;
        spacing = 2 * geometry.spacing;
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
        on-click = ''${pkgs.uwsm}/bin/uwsm app -- alacritty --class wlctl -o 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' -e wlctl'';
      };
      bluetooth = {
        format = ''<span foreground="${roles.bluetooth}"></span>'';
        format-disabled = "";
        format-off = "";
        format-connected = ''<span foreground="${roles.bluetooth}"></span>'';
        tooltip-format = "Bluetooth: {status}\nClick for Bluetooth controls";
        tooltip-format-connected = "{device_enumerate}\nClick for Bluetooth controls";
        tooltip-format-enumerate-connected = "{device_alias}";
        on-click = ''${pkgs.uwsm}/bin/uwsm app -- alacritty --class bluetui -o 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' -e bluetui'';
      };
      pulseaudio = {
        format = ''<span foreground="${roles.audio}">{icon}</span>'';
        format-muted = "󰝟";
        format-bluetooth = ''<span foreground="${roles.audio}">󰂰</span>'';
        format-bluetooth-muted = "󰝟";
        tooltip-format = "{desc}\nVolume: {volume}%\nClick for audio controls · Scroll for volume";
        scroll-step = 5;
        max-volume = 100;
        on-scroll-up = "desktop-feedback volume-up";
        on-scroll-down = "desktop-feedback volume-down";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = ''${pkgs.uwsm}/bin/uwsm app -- alacritty --class wiremix -o 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' -e wiremix'';
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
        tooltip-format = "Battery: {capacity}%\n{timeTo}\nClick for system monitor";
        on-click = ''${pkgs.uwsm}/bin/uwsm app -- alacritty --class system-monitor -o 'window.dimensions={columns=120,lines=36}' -o 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' -e btop'';
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
        font-family: "${typography.family}", "${typography.symbolsFamily}";
        font-size: ${fontSize}pt;
      }
      window#waybar { background: ${roles.background}; color: ${roles.foreground}; border: ${px geometry.borderWidth} solid ${roles.border}; border-radius: ${px geometry.radius}; }
      /* GTK's top-level border does not inset Waybar's child allocation. */
      window#waybar > box { margin: ${px geometry.borderWidth}; }
      #workspaces { background: transparent; }
      #workspaces button { margin: 0; padding: 0 ${px geometry.padding}; min-height: 0; border-radius: 0; color: ${roles.foregroundMuted}; background: transparent; box-shadow: none; text-shadow: none; }
      #workspaces button:hover { background: ${roles.surface}; color: ${roles.foreground}; }
      #workspaces button.visible { color: ${roles.accent}; background: ${roles.backgroundAlt}; }
      #workspaces button:active { background: ${roles.selection}; }
      #workspaces button.urgent { color: ${roles.error}; }
      tooltip.background { background: transparent; border: none; margin: 0; padding: 0; box-shadow: none; }
      /* GTK's tooltip box has fixed 6px widget margins; offset those before
         applying the shared tile inset and the one-border vertical correction. */
      tooltip > box {
        background: ${roles.background}; border: ${px geometry.borderWidth} solid ${roles.border}; border-radius: ${px geometry.radius};
        margin: ${px (geometry.borderWidth - 6)} ${px (geometry.spacing - 6)} -6px -6px; padding: 0;
      }
      tooltip label { color: ${roles.foreground}; padding: ${px geometry.padding}; font-family: "${typography.family}", monospace; text-shadow: none; }
      /* Flat controls with a hover cue; avoid a row of tiny input-like boxes. */
      #network, #bluetooth, #pulseaudio, #power-profiles-daemon, #battery, #custom-notifications {
        background: transparent; border: none;
        border-radius: 0; margin: 0; padding: 0 ${px geometry.padding}; min-width: ${px geometry.iconSize};
      }
      #network:hover, #bluetooth:hover, #pulseaudio:hover, #power-profiles-daemon:hover, #battery:hover, #custom-notifications:hover {
        background: ${roles.surface};
      }
      #bluetooth.off, #bluetooth.disabled, #pulseaudio.muted { color: ${roles.foregroundMuted}; }
      #power-profiles-daemon.performance { color: ${roles.powerPerformance}; }
      #power-profiles-daemon.balanced { color: ${roles.powerBalanced}; }
      #power-profiles-daemon.power-saver { color: ${roles.powerSaver}; }
      #custom-notifications { color: ${roles.notifications}; }
      #app-tray-arrow { min-width: ${px geometry.iconSize}; padding: 0 ${px geometry.padding}; color: ${roles.foregroundMuted}; -gtk-icon-transform: rotate(0deg); transition: -gtk-icon-transform 160ms ease; }
      #app-tray.open #app-tray-arrow { color: ${roles.accent}; -gtk-icon-transform: rotate(180deg); }
      #tray { padding: 0 ${px geometry.padding}; }
      /* An inset warning line preserves the same icon allocation in every state. */
      #battery.warning { color: ${roles.foreground}; box-shadow: inset 0 -${px geometry.borderWidth} 0 ${roles.warning}; }
      #battery.critical, #network.disconnected { color: ${roles.error}; }
      #battery.charging, #battery.plugged, #battery.full { color: ${roles.success}; }
      #clock { padding: 0 ${px geometry.padding}; }
    '';
  };

  services.swayosd = {
    enable = true;
    topMargin = 0.85;
    stylePath = pkgs.writeText "swayosd-style.css" ''
      window#osd {
        background: ${roles.background};
        color: ${roles.foreground};
        border: ${px geometry.borderWidth} solid ${roles.borderFocused};
        border-radius: ${px geometry.radius};
        box-shadow: none;
      }
      window#osd #container { margin: ${px geometry.overlayInset}; }
      window#osd image, window#osd label {
        color: ${roles.foreground};
        font-family: "${typography.family}";
        font-size: ${fontSize}pt;
      }
      window#osd progressbar { min-height: ${px geometry.spacing}; }
      window#osd trough, window#osd progress {
        min-height: ${px geometry.spacing};
        border: none;
        border-radius: ${px (geometry.radius / 2)};
      }
      window#osd trough { background: ${roles.surface}; }
      window#osd progress { background: ${roles.accent}; }
    '';
  };

  services.swaync = {
    enable = true;
    # The pinned UI hardcodes a 96px fallback icon. Keep only its native label;
    # visibility cannot be changed through GTK CSS, so patch this one UI property.
    package = pkgs.swaynotificationcenter.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace data/ui/notifications_widget.blp \
          --replace-fail 'pixel-size: 96;' 'visible: false;'
      '';
    });
    settings = {
      positionX = "right";
      positionY = "top";
      control-center-width = 400;
      notification-window-width = 400;
      # Match the outer tile border, beyond Waybar's reserved screen area.
      control-center-margin-top = geometry.spacing;
      control-center-margin-right = geometry.spacing;
      control-center-margin-bottom = geometry.spacing;
      fit-to-screen = false;
      # Keep an empty panel useful too; layer-shell caps this on smaller outputs.
      control-center-height = 600;
      timeout = 5;
      text-empty = "No notifications";
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
        --border-radius: ${px geometry.radius};
        --notification-shadow: none;
        --notification-icon-size: ${px (2 * geometry.iconSize)};
        --notification-app-icon-size: ${px geometry.iconSize};
        --notification-group-icon-size: ${px (geometry.controlHeight - geometry.spacing)};
        --font-size-body: ${fontSize}pt;
        --font-size-summary: ${fontSize}pt;
      }
      * {
        font-family: "${typography.family}", "${typography.symbolsFamily}";
        font-size: ${fontSize}pt;
        text-shadow: none;
        -gtk-icon-shadow: none;
      }
      .control-center { border: ${px geometry.borderWidth} solid ${roles.border}; padding: ${px geometry.spacing}; }
      /* Hide the scrollbar indicator while retaining wheel/touchpad scrolling. */
      .control-center scrollbar { opacity: 0; }
      .control-center .control-center-list-placeholder {
        opacity: 1;
        color: ${roles.foregroundMuted};
        padding: ${px geometry.overlayInset};
      }
      .widget { margin: 0; padding: ${px geometry.spacing}; }
      .widget-title > label, .widget-dnd > label { font-size: ${fontSize}pt; }
      .widget-title > label { font-weight: bold; }
      .widget-dnd { margin-bottom: ${px geometry.spacing}; }
      .control-center button, .notification button, .close-button {
        background-image: none;
        background-color: transparent;
        color: ${roles.foreground};
        border: none;
        border-radius: ${px geometry.radius};
        box-shadow: none;
        min-height: ${px geometry.controlHeight};
        padding: ${px (geometry.spacing / 2)} ${px geometry.padding};
      }
      .notification-group, .notification-row:focus, .notification-group:focus { background: transparent; }
      .notification-row .notification-background { padding: ${px (geometry.spacing / 2)} ${px geometry.spacing}; }
      /* Match the panel's inset; layer-shell already respects Waybar's space. */
      .floating-notifications { padding: ${px geometry.spacing}; }
      .floating-notifications .notification-row .notification-background { padding: 0; margin-bottom: ${px geometry.spacing}; }
      .notification-row .notification-background .notification .notification-default-action { padding: ${px geometry.padding}; }
      .control-center .notification-group .notification { background: ${roles.background}; }
      .notification-group .notification-group-buttons, .notification-group .notification-group-headers { margin: ${px (geometry.spacing / 2)} ${px geometry.spacing}; }
      .notification-group .notification-group-close-button .close-button { margin: ${px geometry.spacing} ${px (2 * geometry.spacing)}; }
      .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .time {
        color: ${roles.foregroundMuted}; font-weight: normal;
      }
      .notification-row .notification-background .notification .notification-default-action .notification-content .app-icon { -gtk-icon-shadow: none; }
      .notification-row .notification-background .notification.critical { border-color: ${roles.error}; }
      .widget-title > button, .notification .notification-action > button, .widget-dnd switch, .close-button {
        background: ${roles.surface}; color: ${roles.foreground};
        border: ${px geometry.borderWidth} solid ${roles.border}; border-radius: ${px geometry.radius}; box-shadow: none;
      }
      .widget-title > button:hover, .notification .notification-action > button:hover, .close-button:hover { background: ${roles.selection}; }
      /* GTK dims disabled labels as well as recoloring them. Keep Clear All
         readable when the list is empty, while retaining its disabled state. */
      .widget-title > button, .widget-title > button label { opacity: 1; filter: none; }
      .widget-title > button label { color: inherit; }
      .widget-title > button:disabled { background: ${roles.backgroundAlt}; color: ${roles.foregroundMuted}; }
      .control-center button:focus-visible, .notification button:focus-visible { outline: ${px geometry.borderWidth} solid ${roles.borderFocused}; outline-offset: -${px geometry.borderWidth}; }
      .notification-row .notification-background .notification .notification-action { margin: 0 ${px (geometry.spacing / 2)}; }
      .close-button { min-width: ${px (geometry.controlHeight - geometry.spacing)}; min-height: ${
        px (geometry.controlHeight - geometry.spacing)
      }; padding: 0; margin-top: ${px geometry.spacing}; margin-right: ${px geometry.padding}; }
      .widget-dnd switch { min-height: ${px (geometry.controlHeight - geometry.spacing)}; }
      .widget-dnd switch:checked { background: ${roles.accent}; }
      .widget-dnd switch slider { background: ${roles.background}; border-radius: ${
        px (geometry.radius - geometry.borderWidth)
      }; box-shadow: none; min-width: ${px geometry.iconSize}; min-height: ${px geometry.iconSize}; }
    '';
  };

  # Reloadable policy only: never restart the compositor to apply this drop-in.
  xdg.configFile."systemd/user/wayland-wm@.service.d/10-oom-policy.conf".text = ''
    [Service]
    OOMPolicy=continue
  '';

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

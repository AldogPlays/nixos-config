{
  config,
  lib,
  pkgs,
  desktopTheme,
  ...
}:

let
  theme = desktopTheme;
  inherit (theme)
    terminal
    syntax
    roles
    typography
    geometry
    ;
  px = value: "${toString value}px";
  # Rasi uses #rrggbbaa; keep canonical colors opaque and translate alpha here.
  glassBackground =
    roles.background
    + lib.fixedWidthString 2 "0" (lib.toHexString (builtins.floor (theme.material.opacity * 255)));
  # Discord's current semantic tokens, plus legacy tokens still used by Vencord.
  vesktopColors =
    lib.genAttrs [
      "background-primary"
      "background-base-low"
      "background-surface-high"
      "modal-background"
      "bg-base-primary"
      "input-background-default"
    ] (_: roles.background)
    // lib.genAttrs [
      "background-secondary"
      "background-secondary-alt"
      "background-tertiary"
      "background-base-lower"
      "background-base-lowest"
      "background-floating"
      "modal-footer-background"
      "bg-base-secondary"
      "bg-base-tertiary"
    ] (_: roles.backgroundAlt)
    // lib.genAttrs [
      "background-accent"
      "background-surface-higher"
      "background-surface-highest"
      "background-mod-subtle"
      "background-mod-muted"
      "background-mod-normal"
      "channeltextarea-background"
      "chat-background-default"
      "background-gradient-highest"
      "input-background"
      "button-secondary-background"
      "background-feedback-critical"
      "background-feedback-warning"
      "background-feedback-positive"
      "background-feedback-info"
      "background-feedback-mod-critical"
      "background-feedback-mod-warning"
      "background-feedback-mod-positive"
      "background-feedback-mod-info"
    ] (_: roles.surface)
    // lib.genAttrs [
      "text-normal"
      "text-default"
      "text-strong"
      "header-primary"
      "interactive-hover"
      "interactive-text-hover"
      "interactive-icon-hover"
      "control-icon-only-icon-default"
      "control-icon-only-icon-hover"
      "control-icon-only-icon-active"
      "input-icon-default"
      "icon-default"
      "icon-strong"
      "input-text-default"
    ] (_: roles.foreground)
    // lib.genAttrs [
      "text-muted"
      "text-subtle"
      "header-secondary"
      "interactive-muted"
      "interactive-normal"
      "interactive-text-default"
      "interactive-icon-default"
      "channels-default"
      "channel-icon"
      "channel-text-area-placeholder"
      "chat-text-muted"
      "input-placeholder-text-default"
      "icon-muted"
      "icon-subtle"
      "icon-status-offline"
    ] (_: roles.foregroundMuted)
    // lib.genAttrs [
      "interactive-active"
      "interactive-text-active"
      "interactive-icon-active"
    ] (_: roles.selectionForeground)
    // lib.genAttrs [
      "text-link"
      "text-brand"
      "background-brand"
      "brand-500"
      "brand-560"
      "brand-600"
      "control-brand-foreground"
      "control-brand-foreground-new"
      "icon-brand"
      "icon-link"
      "border-focus"
      "input-border-active"
    ] (_: roles.accent)
    // lib.genAttrs [
      "border-subtle"
      "border-muted"
      "border-normal"
      "border-strong"
      "input-border-default"
      "input-border-hover"
      "input-border-readonly"
    ] (_: roles.border)
    // lib.genAttrs [
      "background-modifier-hover"
      "background-modifier-active"
      "background-modifier-selected"
      "background-mod-strong"
      "interactive-background-hover"
      "interactive-background-selected"
      "interactive-background-active"
    ] (_: roles.selection)
    // lib.genAttrs [
      "text-danger"
      "text-feedback-critical"
      "status-danger"
      "text-status-dnd"
      "border-feedback-critical"
      "icon-feedback-critical"
      "icon-status-dnd"
    ] (_: roles.error)
    // lib.genAttrs [
      "text-positive"
      "text-feedback-positive"
      "status-positive"
      "status-online"
      "status-speaking"
      "text-status-online"
      "border-feedback-positive"
      "icon-feedback-positive"
      "icon-status-online"
    ] (_: roles.success)
    // {
      "text-feedback-warning" = roles.warning;
      "icon-feedback-warning" = roles.warning;
      "icon-status-idle" = roles.warning;
      "text-status-idle" = roles.warning;
      "text-status-offline" = roles.foregroundMuted;
      "text-feedback-info" = roles.info;
      "icon-feedback-info" = roles.info;
      "icon-feedback-notification" = roles.notifications;
      "icon-invert" = roles.onAccent;
      "text-invert" = roles.onAccent;
      "border-feedback-warning" = roles.warning;
      "border-feedback-info" = roles.info;
      "status-positive-background" = roles.success;
      "status-positive-text" = roles.onSuccess;
      "status-warning-background" = roles.warning;
      "status-warning-text" = roles.onWarning;
    }
    // lib.concatMapAttrs (state: _: {
      "control-primary-background-${state}" = if state == "hover" then roles.foreground else roles.accent;
      "control-primary-text-${state}" = roles.onAccent;
      "control-primary-icon-${state}" = roles.onAccent;
      "control-primary-border-${state}" = "transparent";
      "control-secondary-background-${state}" =
        if state == "default" then roles.surface else roles.selection;
      "control-secondary-text-${state}" = roles.foreground;
      "control-secondary-icon-${state}" = roles.foreground;
      "control-secondary-border-${state}" = roles.border;
    }) (lib.genAttrs [ "default" "hover" "active" ] (_: null));
  darktable = pkgs.symlinkJoin {
    name = "darktable-desktop-${pkgs.darktable.version}";
    paths = [ pkgs.darktable ];
    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.desktop-file-utils
    ];
    postBuild = ''
      rm "$out/bin/darktable"
      makeWrapper ${lib.getExe' pkgs.darktable "darktable"} "$out/bin/darktable" \
        --set-default RUSTICL_ENABLE radeonsi \
        --add-flags '--conf ui_last/theme=desktop --conf use_system_font=true --conf clplatform_rusticl=true'
      desktop="$out/share/applications/org.darktable.darktable.desktop"
      cp --remove-destination ${pkgs.darktable}/share/applications/org.darktable.darktable.desktop "$desktop"
      substituteInPlace "$desktop" --replace-fail '${pkgs.darktable}/bin/darktable' "$out/bin/darktable"
      desktop-file-edit --set-generic-name='Photo editor' "$desktop"
    '';
    meta = pkgs.darktable.meta;
  };
in
{
  home.packages = [ darktable ];

  # Keep the client and its modification pinned together; no downloaded code updater.
  programs.vesktop = {
    enable = true;
    package = pkgs.vesktop.override { vencord = pkgs.callPackage ../../packages/vencord.nix { }; };
    vencord.useSystem = true;
    settings = {
      arRPC = false;
      minimizeToTray = false;
      disableMinSize = true;
    };
    vencord.settings = {
      autoUpdate = false;
      autoUpdateNotification = false;
      useQuickCss = true;
      cloud.settingsSync = false;
      plugins.NoTrack = {
        enabled = true;
        disableAnalytics = true;
      };
    };
    # Cosmetic filters only: Discord still supplies the web application.
    vencord.extraQuickCss = ''
      /* The selected desktop palette applies regardless of Discord's account theme. */
      :root, .theme-dark, .theme-light, .theme-midnight, .theme-darker {
        color-scheme: ${theme.appearance};
        --font-primary: "${typography.family}", sans-serif !important;
        --font-display: "${typography.family}", sans-serif !important;
        --font-headline: "${typography.family}", sans-serif !important;
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: value: "--${name}: ${value} !important;") vesktopColors
        )}
      }
      body, #app-mount {
        background-color: ${roles.background};
        color: ${roles.foreground};
      }
      body, input, textarea, button { font-size: ${toString typography.size}pt; }
      /* Discord hardcodes white on these themed accent fills. */
      [class*="wrapper_"][class*="selected_"] [class*="childWrapper_"],
      [class*="wrapper_"]:hover [class*="childWrapper_"] {
        color: ${roles.onAccent} !important;
      }
      [class*="tabBar_"] [class*="addFriend_"] {
        color: ${roles.onAccent} !important;
      }
      [class*="tabBar_"] [class*="addFriend_"][aria-selected="true"] {
        background-color: ${roles.selection} !important;
        color: ${roles.selectionForeground} !important;
      }
      /* Custom account backgrounds otherwise force a translucent placeholder. */
      [class*="channelTextArea_"] [class*="placeholder_"] {
        color: ${roles.foregroundMuted} !important;
      }
      /* Replace login decoration only; avatars, attachments and video keep their colors. */
      [class*="characterBackground_"] { background: ${roles.background} !important; }
      [class*="characterBackground_"] [class*="artwork_"] { display: none; }
      [class*="characterBackground_"] [class*="logoWithText_"] {
        filter: ${if theme.appearance == "light" then "brightness(0)" else "none"};
      }
      [class*="authBox_"] {
        border: ${px geometry.borderWidth} solid ${roles.border};
        border-radius: ${px geometry.radius};
        box-shadow: none;
      }

      /* Store, Nitro and sponsored Quest entry points. */
      a[href="/store"],
      a[href="/shop"],
      a[href="/quests"],
      a[href="/quest-home"],
      a[href="/discovery/quests"],
      [class*="questsWrapper_"],
      [class*="questPromo_"],
      [class*="premiumTab_"],
      [class*="giftCodeButton_"],
      [class*="premiumUpsell_"],
      [class*="nitroUpsell_"] {
        display: none !important;
      }
      /* Quest reward cards above the account controls, not the controls themselves. */
      [class*="panels_"] [class*="mask_"]:has([class*="reward"]) {
        display: none !important;
      }
    '';
  };

  # On-demand monitor, sharing the terminal's palette rather than a second theme.
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "desktop";
      theme_background = true;
      rounded_corners = false;
      show_battery = true;
    };
    themes.desktop = ''
      theme[main_bg]="${roles.background}"
      theme[main_fg]="${roles.foreground}"
      theme[title]="${roles.foreground}"
      theme[hi_fg]="${roles.accent}"
      theme[selected_bg]="${roles.selection}"
      theme[selected_fg]="${roles.selectionForeground}"
      theme[inactive_fg]="${roles.foregroundMuted}"
      theme[graph_text]="${roles.foreground}"
      theme[meter_bg]="${roles.surface}"
      theme[proc_misc]="${roles.accent}"
      theme[cpu_box]="${roles.border}"
      theme[mem_box]="${roles.border}"
      theme[net_box]="${roles.border}"
      theme[proc_box]="${roles.border}"
      theme[div_line]="${roles.border}"
      theme[temp_start]="${roles.success}"
      theme[temp_mid]="${roles.warning}"
      theme[temp_end]="${roles.error}"
      theme[cpu_start]="${roles.accent}"
      theme[cpu_mid]="${roles.accent}"
      theme[cpu_end]="${roles.accent}"
      theme[free_start]="${roles.success}"
      theme[free_mid]="${roles.success}"
      theme[free_end]="${roles.success}"
      theme[cached_start]="${roles.info}"
      theme[cached_mid]="${roles.info}"
      theme[cached_end]="${roles.info}"
      theme[available_start]="${roles.success}"
      theme[available_mid]="${roles.success}"
      theme[available_end]="${roles.success}"
      theme[used_start]="${roles.accent}"
      theme[used_mid]="${roles.warning}"
      theme[used_end]="${roles.error}"
      theme[download_start]="${roles.network}"
      theme[download_mid]="${roles.network}"
      theme[download_end]="${roles.network}"
      theme[upload_start]="${roles.info}"
      theme[upload_mid]="${roles.info}"
      theme[upload_end]="${roles.info}"
      theme[process_start]="${roles.foreground}"
      theme[process_mid]="${roles.accent}"
      theme[process_end]="${roles.accent}"
    '';
  };

  # Only the stylesheet is managed; preferences, catalogues and edits stay writable.
  # Native --conf overrides select it without rewriting darktablerc on exit.
  xdg.configFile."darktable/themes/desktop.css".text = ''
    @import url("${pkgs.darktable}/share/darktable/themes/darktable.css");

    @define-color selected_bg_color ${roles.selection};
    @define-color border_color ${roles.border};
    @define-color bg_color ${roles.background};
    @define-color fg_color ${roles.foreground};
    @define-color base_color ${roles.foreground};
    @define-color text_color ${roles.foreground};
    @define-color placeholder_text_color ${roles.foregroundMuted};
    @define-color disabled_fg_color alpha(${roles.foreground}, 0.4);
    @define-color scroll_bar_inactive ${roles.border};
    @define-color scroll_bar_active ${roles.accent};
    @define-color scroll_bar_bg ${roles.backgroundAlt};
    @define-color plugin_bg_color ${roles.backgroundAlt};
    @define-color section_label ${roles.foreground};
    @define-color plugin_label_color ${roles.foregroundMuted};
    @define-color collapsible_bg_color ${roles.surface};
    @define-color bauhaus_bg ${roles.background};
    @define-color bauhaus_fg ${roles.foreground};
    @define-color bauhaus_border ${roles.border};
    @define-color bauhaus_indicator_border ${roles.border};
    @define-color bauhaus_fill ${roles.accent};
    @define-color bauhaus_bg_hover ${roles.selection};
    @define-color bauhaus_fg_hover ${roles.selectionForeground};
    @define-color bauhaus_fg_selected ${roles.selectionForeground};
    @define-color bauhaus_fg_insensitive alpha(${roles.foreground}, 0.4);
    @define-color button_bg ${roles.surface};
    @define-color button_fg ${roles.foreground};
    @define-color button_border ${roles.border};
    @define-color button_hover_bg ${roles.selection};
    @define-color button_hover_fg ${roles.selectionForeground};
    @define-color field_bg ${roles.background};
    @define-color field_fg ${roles.foreground};
    @define-color field_active_bg ${roles.backgroundAlt};
    @define-color field_active_fg ${roles.foreground};
    @define-color field_selected_bg ${roles.selection};
    @define-color field_selected_fg ${roles.selectionForeground};
    @define-color field_hover_bg ${roles.selection};
    @define-color field_hover_fg ${roles.selectionForeground};
    @define-color tooltip_bg_color ${roles.background};
    @define-color tooltip_fg_color ${roles.foreground};
    @define-color really_dark_bg_color ${roles.backgroundAlt};
    @define-color log_fg_color ${roles.foreground};

    /* Preserve native neutral image surrounds, graphs and functional color swatches. */
    * { font-family: "${typography.family}"; }
  '';

  programs.librewolf = {
    enable = true;
    policies = {
      DefaultDownloadDirectory = config.xdg.userDirs.download;
      PromptForDownloadLocation = false;
      # The pinned Linux build disables automatic low-memory tab unloading.
      Preferences."browser.tabs.unloadOnLowMemory" = {
        Value = true;
        Status = "default";
      };
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [ "ignoreboth" ];
    # Load before completion/Starship, attach only after their initialization.
    initExtra = lib.mkMerge [
      (lib.mkOrder 50 ''
        if [[ $TERM != dumb && -t 0 && -t 1 ]]; then
          source ${pkgs.blesh}/share/blesh/ble.sh --noattach --rcfile ${pkgs.writeText "blerc" ''
            bleopt complete_auto_history=1
            bleopt complete_auto_complete=1
            bleopt complete_auto_delay=200
            bleopt editor=nano
            ble-face auto_complete='fg=${roles.foregroundMuted},italic'
            ble-face region='fg=${roles.selectionForeground},bg=${roles.selection}'
            ble-face disabled='fg=${roles.foregroundMuted}'
            ble-face syntax_error='fg=${roles.error},underline'
            ble-face syntax_command='fg=${roles.accent}'
            ble-face syntax_comment='fg=${roles.foregroundMuted}'
            ble-face syntax_quoted='fg=${roles.success}'
            ble-face syntax_quotation='fg=${roles.success},bold'
            ble-face syntax_varname='fg=${syntax.variable}'
            ble-face syntax_param_expansion='fg=${syntax.parameter}'
            ble-face command_builtin='fg=${roles.accent}'
            ble-face command_alias='fg=${roles.info}'
            ble-face command_function='fg=${syntax.function}'
            ble-face command_file='fg=${roles.accent}'
            ble-face filename_directory='fg=${roles.accent},underline'
            ble-face filename_link='fg=${roles.info},underline'
          ''}
        fi
      '')
      (lib.mkOrder 2000 ''
        [[ ! ''${BLE_VERSION-} ]] || ble-attach
      '')
    ];
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/Projects/nixos-config#nixos";
      nix-check = "nix flake check ~/Projects/nixos-config";
      ll = "ls -alF";
      # Interactive only: scripts retain coreutils; `command ls` bypasses this.
      ls = "${lib.getExe pkgs.eza} --group-directories-first --git --color=auto --icons=auto";
    };
  };

  programs.eza = {
    enable = true;
    enableBashIntegration = false;
    theme = {
      filekinds = {
        normal.foreground = roles.foreground;
        directory = {
          foreground = roles.accent;
          is_bold = true;
        };
        symlink.foreground = roles.info;
        executable.foreground = roles.success;
      };
      git = {
        new.foreground = roles.success;
        modified.foreground = roles.accent;
        deleted.foreground = roles.error;
        conflicted.foreground = roles.error;
        ignored.foreground = roles.foregroundMuted;
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      light = theme.appearance == "light";
      line-numbers = true;
      navigate = true;
      # Native diff highlighting, not a separately cached bat syntax palette.
      syntax-theme = "none";
      keep-plus-minus-markers = true;
      minus-style = "${roles.error} normal";
      minus-emph-style = "${roles.error} bold ul";
      plus-style = "${roles.success} normal";
      plus-emph-style = "${roles.success} bold ul";
      zero-style = "${roles.foreground} normal";
      file-style = "${roles.accent} bold";
      file-decoration-style = "none";
      hunk-header-style = "file line-number ${roles.foregroundMuted}";
      hunk-header-file-style = roles.foregroundMuted;
      hunk-header-line-number-style = roles.foregroundMuted;
      hunk-header-decoration-style = "none";
      line-numbers-left-style = roles.foregroundMuted;
      line-numbers-right-style = roles.foregroundMuted;
      line-numbers-minus-style = roles.error;
      line-numbers-plus-style = roles.success;
      line-numbers-zero-style = roles.foregroundMuted;
      blame-palette = "${roles.background} ${roles.backgroundAlt} ${roles.surface}";
    };
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$character";
      directory = {
        format = "[$path]($style)[$read_only]($read_only_style) ";
        style = "bold ${roles.accent}";
        read_only = " ro";
        read_only_style = roles.foregroundMuted;
        truncation_length = 3;
      };
      git_branch = {
        format = "[$branch]($style) ";
        style = roles.foreground;
      };
      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = roles.foregroundMuted;
      };
      character = {
        success_symbol = "[❯](${roles.accent})";
        error_symbol = "[❯](${roles.error})";
        vimcmd_symbol = "[❮](${roles.accent})";
      };
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.rofi = {
    enable = true;
    font = "${typography.family} ${toString typography.size}";
    terminal = "alacritty";
    extraConfig = {
      run-command = "${pkgs.uwsm}/bin/uwsm app -- {cmd}";
      run-shell-command = "${pkgs.uwsm}/bin/uwsm app -- {terminal} -e {cmd}";
      drun-display-format = "{name} [<span size='small'>({generic})</span>]";
      drun-match-fields = "name,generic,exec,categories,keywords";
    };
    modes = [
      "drun"
      "run"
    ];
    # Native Rasi; reference port informs selectors, not a second color source.
    theme = toString (
      pkgs.writeText "desktop.rasi" ''
        @theme "default"
        * {
          background: ${glassBackground};
          foreground: ${roles.foreground};
          /* Default-layout aliases must follow the selected preset too. */
          lightfg: ${roles.foregroundMuted};
          lightbg: ${roles.backgroundAlt};
          red: ${roles.error};
          blue: ${roles.accent};
          background-color: transparent;
          text-color: @foreground;
          border-color: ${roles.border};
          normal-background: transparent;
          normal-foreground: @foreground;
          alternate-normal-background: transparent;
          alternate-normal-foreground: @foreground;
          selected-normal-background: ${roles.selection};
          selected-normal-foreground: ${roles.selectionForeground};
          active-background: transparent;
          active-foreground: ${roles.accent};
          alternate-active-background: transparent;
          alternate-active-foreground: ${roles.accent};
          selected-active-background: ${roles.accent};
          selected-active-foreground: ${roles.onAccent};
          urgent-background: transparent;
          urgent-foreground: ${roles.error};
          alternate-urgent-background: transparent;
          alternate-urgent-foreground: ${roles.error};
          selected-urgent-background: ${roles.error};
          selected-urgent-foreground: ${roles.onError};
          separatorcolor: ${roles.border};
          spacing: ${px (geometry.spacing / 2)};
        }
        window { background-color: @background; border: ${px geometry.borderWidth}; border-color: ${roles.borderFocused}; border-radius: ${px geometry.radius}; padding: ${px geometry.padding}; }
        element { padding: ${px geometry.spacing}; border: 0px; }
        element-text, element-icon { background-color: transparent; text-color: inherit; }
        entry { placeholder-color: ${roles.foregroundMuted}; }
        overlay { background-color: ${roles.surface}; text-color: ${roles.foreground}; }
        listview, message, sidebar { border: ${px geometry.borderWidth} 0px 0px; border-color: ${roles.border}; }
        num-filtered-rows, num-rows, textbox-num-sep { text-color: ${roles.foregroundMuted}; }
      ''
    );
  };

  programs.alacritty = {
    enable = true;
    settings = {
      colors = {
        primary = {
          background = roles.background;
          foreground = roles.foreground;
          dim_foreground = roles.foregroundMuted;
          bright_foreground = roles.foreground;
        };
        cursor = {
          text = roles.onAccent;
          cursor = roles.accent;
        };
        vi_mode_cursor = {
          text = terminal.onViCursor;
          cursor = terminal.viCursor;
        };
        selection = {
          text = roles.selectionForeground;
          background = roles.selection;
        };
        search = {
          matches = {
            foreground = roles.onForegroundMuted;
            background = roles.foregroundMuted;
          };
          focused_match = {
            foreground = roles.onAccent;
            background = roles.accent;
          };
        };
        footer_bar = {
          foreground = roles.foreground;
          background = roles.backgroundAlt;
        };
        hints = {
          start = {
            foreground = roles.onAccent;
            background = roles.accent;
          };
          end = {
            foreground = roles.foreground;
            background = roles.surface;
          };
        };
        normal = terminal.normal;
        bright = terminal.bright;
        indexed_colors = terminal.indexed;
      };
      font = {
        normal.family = typography.family;
        size = typography.size;
      };
      window.padding = {
        x = geometry.spacing;
        y = geometry.spacing;
      };
      # Hyprland applies focus-dependent terminal opacity. Avoid multiplying it
      # with Alacritty's native alpha, which would make the background too faint.
      window.opacity = 1.0;
      scrolling.history = 10000;
    };
  };
}

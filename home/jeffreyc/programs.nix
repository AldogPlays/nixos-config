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

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
in
{
  programs.librewolf = {
    enable = true;
    policies = {
      DefaultDownloadDirectory = config.xdg.userDirs.download;
      PromptForDownloadLocation = false;
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

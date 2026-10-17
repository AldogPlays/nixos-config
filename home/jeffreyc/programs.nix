{ pkgs, ... }:

let
  theme = import ../../theme;
  inherit (theme) palette roles typography;
  ansi = {
    black = palette.surface1;
    red = palette.red;
    green = palette.green;
    yellow = palette.yellow;
    blue = palette.blue;
    magenta = palette.pink;
    cyan = palette.teal;
    white = palette.subtext1;
  };
in
{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [ "ignoreboth" ];
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/Projects/nixos-config#nixos";
      nix-check = "nix flake check ~/Projects/nixos-config";
      ll = "ls -alF";
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
    modes = [
      "drun"
      "run"
    ];
    # Native Rasi; reference port informs selectors, not a second color source.
    theme = toString (
      pkgs.writeText "latte.rasi" ''
        @theme "default"
        * {
          background: ${roles.background};
          foreground: ${roles.foreground};
          background-color: transparent;
          text-color: @foreground;
          border-color: ${roles.border};
          normal-background: @background;
          normal-foreground: @foreground;
          alternate-normal-background: ${roles.backgroundAlt};
          alternate-normal-foreground: @foreground;
          selected-normal-background: ${roles.selection};
          selected-normal-foreground: @foreground;
          active-background: @background;
          active-foreground: ${roles.accent};
          alternate-active-background: ${roles.backgroundAlt};
          alternate-active-foreground: ${roles.accent};
          selected-active-background: ${roles.accent};
          selected-active-foreground: ${roles.background};
          urgent-background: @background;
          urgent-foreground: ${roles.error};
          alternate-urgent-background: ${roles.backgroundAlt};
          alternate-urgent-foreground: ${roles.error};
          selected-urgent-background: ${roles.error};
          selected-urgent-foreground: ${roles.background};
          separatorcolor: ${roles.border};
          spacing: 2px;
        }
        window { background-color: @background; border: 1px; border-radius: 4px; padding: 6px; }
        element { padding: 3px; border: 0px; }
        element-text, element-icon { background-color: transparent; text-color: inherit; }
        entry { placeholder-color: ${roles.foregroundMuted}; }
        listview, message, sidebar { border: 1px 0px 0px; border-color: ${roles.border}; }
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
          text = roles.background;
          cursor = roles.accent;
        };
        vi_mode_cursor = {
          text = roles.background;
          cursor = palette.lavender;
        };
        selection = {
          text = roles.foreground;
          background = roles.selection;
        };
        search = {
          matches = {
            foreground = roles.background;
            background = roles.foregroundMuted;
          };
          focused_match = {
            foreground = roles.background;
            background = roles.accent;
          };
        };
        footer_bar = {
          foreground = roles.foreground;
          background = roles.backgroundAlt;
        };
        hints = {
          start = {
            foreground = roles.background;
            background = roles.accent;
          };
          end = {
            foreground = roles.foreground;
            background = roles.surface;
          };
        };
        normal = ansi;
        bright = ansi // {
          black = palette.surface2;
          white = palette.subtext0;
        };
        indexed_colors = [
          {
            index = 16;
            color = palette.peach;
          }
          {
            index = 17;
            color = palette.rosewater;
          }
        ];
      };
      font = {
        normal.family = typography.family;
        size = typography.size;
      };
      window.padding = {
        x = 4;
        y = 4;
      };
      scrolling.history = 10000;
    };
  };
}

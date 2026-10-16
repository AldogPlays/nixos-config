{ config, pkgs, ... }:

{
  xdg.configFile."hypr/hyprland.lua".source = ../../dotfiles/hypr/hyprland.lua;

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 8;
      modules-left = [
        "hyprland/workspaces"
        "hyprland/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "network"
        "pulseaudio"
        "battery"
        "tray"
      ];
      clock.format = "{:%a %b %d  %H:%M}";
      network = {
        format-wifi = "{essid}  {signalStrength}%";
        format-ethernet = "Ethernet";
        format-disconnected = "Offline";
        tooltip-format = "{ifname}: {ipaddr}/{cidr}";
      };
      pulseaudio = {
        format = "{volume}% {icon}";
        format-muted = "Muted";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = "pavucontrol";
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
    };
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 12px;
      }
      window#waybar { background: rgba(20, 22, 30, 0.92); color: #d8dee9; }
      #workspaces button { padding: 0 7px; color: #7f849c; }
      #workspaces button.active { color: #89b4fa; }
      #clock, #network, #pulseaudio, #battery, #tray { padding: 0 8px; }
    '';
  };

  services.mako = {
    enable = true;
    settings = {
      anchor = "top-right";
      background-color = "#1e1e2eee";
      border-color = "#89b4faff";
      border-radius = 8;
      border-size = 2;
      default-timeout = 5000;
      font = "JetBrainsMono Nerd Font 10";
      text-color = "#cdd6f4ff";
    };
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

    network-manager-applet = {
      Unit = {
        Description = "NetworkManager tray applet";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}

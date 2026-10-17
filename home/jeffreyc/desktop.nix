{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Keep nixpkgs' Hyprland/compiler pairing, with upstream's compatible Lua source.
  hyprspace = pkgs.hyprlandPlugins.hyprspace.overrideAttrs (_: {
    src = inputs.hyprspace-src;
    version = "0-unstable-${inputs.hyprspace-src.shortRev}";
  });
in
{
  # Render only the pinned plugin path; colors are not connected to theme/ yet.
  xdg.configFile."hypr/hyprland.lua".source = pkgs.writeText "hyprland.lua" (
    builtins.replaceStrings [ "@HYPRSPACE_PLUGIN@" ] [ "${hyprspace}/lib/libhyprspace.so" ] (
      builtins.readFile ../../dotfiles/hypr/hyprland.lua
    )
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
        font-family: "Monaspace Neon", "Symbols Nerd Font";
        font-size: 11px;
      }
      window#waybar { background: rgba(20, 22, 30, 0.92); color: #d8dee9; }
      #workspaces button { padding: 0 5px; color: #7f849c; }
      #workspaces button.active { color: #89b4fa; }
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
      * { font-family: "Monaspace Neon", "Symbols Nerd Font"; }
      .notification { border-radius: 4px; box-shadow: none; }
    '';
  };

  services.wpaperd = {
    enable = true;
    settings.default = {
      # Reproducible placeholder until a personal wallpaper is selected.
      path = pkgs.nixos-artwork.wallpapers.simple-dark-gray.gnomeFilePath;
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

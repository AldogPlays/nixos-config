{ pkgs, ... }:

let
  # Match the saved home connection, independently of its display name.
  homeConnectionUUID = "cd6aec24-86fd-45cf-9094-efc634ba414a";
  vpnPolicy = pkgs.writeShellApplication {
    name = "hermes-vpn-policy";
    runtimeInputs = [
      pkgs.python3
      pkgs.networkmanager
    ];
    text = ''
      exec python3 ${../../scripts/hermes-vpn-policy.py} --home-uuid ${homeConnectionUUID} "$@"
    '';
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/core.nix
    ../../modules/nixos/hardware.nix
    ../../modules/nixos/hyprland.nix
  ];

  networking.hostName = "nixos";
  home-manager.users.jeffreyc = {
    _module.args.monitorConfiguration = ./monitors.lua;
    # Prefer the desk interface when present, with ordinary fallback when unplugged.
    # A user fragment avoids restarting the running audio session on activation.
    xdg.configFile."wireplumber/wireplumber.conf.d/51-rode-ai1.conf".text = builtins.toJSON {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_output.usb-RODE_Microphones_RODE_AI-1_.*"; } ];
          actions.update-props."priority.session" = 1450;
        }
        {
          matches = [ { "node.name" = "~alsa_input.usb-RODE_Microphones_RODE_AI-1_.*"; } ];
          actions.update-props."priority.session" = 2450;
        }
      ];
    };
  };
  security.pki.certificateFiles = [ ./certificates/hermes-root-ca.crt ];

  # NetworkManager supplies per-link DNS; the VPN routes only home.arpa to Hermes.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      # Keep discovery with Avahi and DNS with the current connection's resolvers.
      LLMNR = false;
      MulticastDNS = false;
      FallbackDNS = [ ];
    };
  };
  # DNS backend changes can be reloaded without interrupting the Wi-Fi link.
  systemd.services.NetworkManager.reloadIfChanged = true;

  # Pin only this laptop's saved home profile; keep its credentials outside Nix.
  # A BSSID lock disables background roaming scans during remote play.
  systemd.services.hermes-wifi-pin = {
    description = "Pin home Wi-Fi to the 5 GHz access point";
    wantedBy = [ "multi-user.target" ];
    wants = [ "NetworkManager.service" ];
    after = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.networkmanager}/bin/nmcli connection modify uuid ${homeConnectionUUID} \
        802-11-wireless.bssid 94:83:C4:E5:56:DE
    '';
  };

  # The existing dispatcher reconciles the VPN on network changes; no daemon/timer.
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeShellScript "hermes-vpn-dispatcher" ''
        exec ${vpnPolicy}/bin/hermes-vpn-policy "$@"
      '';
    }
  ];

  # Import credentials at runtime into a root-only NetworkManager keyfile.
  environment.systemPackages = [
    vpnPolicy
    (pkgs.writeShellApplication {
      name = "hermes-vpn-import";
      runtimeInputs = [
        pkgs.python3
        pkgs.networkmanager
      ];
      text = ''
        exec python3 ${../../scripts/import-hermes-vpn.py} "$@"
      '';
    })
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.jeffreyc = {
    isNormalUser = true;
    description = "Jeffrey Conton";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # Preserve this install's compatibility baseline. Do not update this when
  # updating NixOS; it is unrelated to the selected nixpkgs release.
  system.stateVersion = "26.05";
}

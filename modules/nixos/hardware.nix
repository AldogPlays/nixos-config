{ pkgs, ... }:

let
  powerPython = pkgs.python3.withPackages (p: [ p.pygobject3 ]);
in
{
  hardware = {
    enableRedistributableFirmware = true;
    graphics.enable = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  services = {
    fwupd.enable = true;
    power-profiles-daemon.enable = true;
    upower.enable = true;
  };

  environment.systemPackages = [ pkgs.libva-utils ];

  # Event-driven policy only; the existing daemon still applies hardware tuning.
  systemd.services.power-source-profile = {
    description = "Select a power profile from AC and battery state";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "upower.service"
      "power-profiles-daemon.service"
    ];
    after = [
      "upower.service"
      "power-profiles-daemon.service"
    ];
    environment.GI_TYPELIB_PATH = "${pkgs.glib.out}/lib/girepository-1.0";
    serviceConfig = {
      ExecStart = "${powerPython}/bin/python3 ${../../scripts/power-source-profile.py}";
      Restart = "on-failure";
      RestartSec = 3;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
  };
}

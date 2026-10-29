{ pkgs, ... }:

let
  powerPython = pkgs.python3.withPackages (p: [ p.pygobject3 ]);
  batteryCharge = pkgs.writeShellApplication {
    name = "battery-charge";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../../scripts/battery-charge.py} "$@"
    '';
  };
in
{
  hardware = {
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      # Mesa's OpenCL output supplies GPU photo processing without a ROCm stack.
      extraPackages = [ pkgs.mesa.opencl ];
    };
    # Match SDR++'s V4-capable driver; install USB rules and block DVB claiming it.
    rtl-sdr = {
      enable = true;
      package = pkgs.rtl-sdr-osmocom;
    };
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

  environment.systemPackages = [
    pkgs.libva-utils
    batteryCharge
  ];

  # Apply a firmware preset once, then exit; manual full charging lasts to reboot.
  systemd.services.battery-charge-limit = {
    description = "Enable firmware battery conservation where supported";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-trigger.service" ];
    # Driver extensions attach the charge_types attribute during device discovery.
    preStart = ''
      if ! ${pkgs.systemd}/bin/udevadm settle --timeout=10; then
        echo "Device discovery is still busy; checking available battery controls."
      fi
    '';
    # A routine rebuild must not undo an intentional full-charge override.
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${batteryCharge}/bin/battery-charge protect";
      RemainAfterExit = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
  };

  # Event-driven profiles and low-battery backlight cap; no polling or new daemon.
  systemd.services.power-source-profile = {
    description = "Select a power profile from AC and battery state";
    # The packaged power daemon starts after multi-user.target.
    wantedBy = [ "graphical.target" ];
    wants = [
      "upower.service"
      "power-profiles-daemon.service"
    ];
    after = [
      "upower.service"
      "power-profiles-daemon.service"
    ];
    environment = {
      GI_TYPELIB_PATH = "${pkgs.glib.out}/lib/girepository-1.0";
      LOW_BATTERY_BRIGHTNESS_PERCENT = "30";
    };
    serviceConfig = {
      ExecStart = "${powerPython}/bin/python3 ${../../scripts/power-source-profile.py}";
      Restart = "on-failure";
      RestartSec = 3;
      RuntimeDirectory = "power-source-profile";
      RuntimeDirectoryPreserve = "restart";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
  };
}

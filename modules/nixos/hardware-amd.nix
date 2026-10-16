{ pkgs, ... }:

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
    blueman.enable = true;
    fwupd.enable = true;
    power-profiles-daemon.enable = true;
    upower.enable = true;
  };

  environment.systemPackages = [ pkgs.libva-utils ];
}

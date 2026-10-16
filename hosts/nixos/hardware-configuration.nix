# Generated from the installed machine's configuration on 2026-10-16.
# Disk UUIDs are host-specific; do not reuse this file on another machine.
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/mapper/luks-37a5048c-12ef-4a44-bad4-0236bbb301e2";
    fsType = "btrfs";
  };

  boot.initrd.luks.devices."luks-37a5048c-12ef-4a44-bad4-0236bbb301e2".device =
    "/dev/disk/by-uuid/37a5048c-12ef-4a44-bad4-0236bbb301e2";

  fileSystems."/home" = {
    device = "/dev/mapper/luks-37a5048c-12ef-4a44-bad4-0236bbb301e2";
    fsType = "btrfs";
    options = [ "subvol=home" ];
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/luks-37a5048c-12ef-4a44-bad4-0236bbb301e2";
    fsType = "btrfs";
    options = [ "subvol=nix" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/FC38-9259";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  boot.initrd.luks.devices."luks-0c3d5683-051d-4417-9909-736d7d45680f".device =
    "/dev/disk/by-uuid/0c3d5683-051d-4417-9909-736d7d45680f";

  swapDevices = [
    { device = "/dev/mapper/luks-0c3d5683-051d-4417-9909-736d7d45680f"; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

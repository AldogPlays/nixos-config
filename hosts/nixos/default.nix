{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/core.nix
    ../../modules/nixos/hardware.nix
    ../../modules/nixos/hyprland.nix
  ];

  networking.hostName = "nixos";
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

{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/core.nix
    ../../modules/nixos/hardware-amd.nix
    ../../modules/nixos/hyprland.nix
  ];

  networking.hostName = "nixos";

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

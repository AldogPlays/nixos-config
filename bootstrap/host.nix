{ lib, pkgs, ... }:
let
  host = builtins.fromJSON (builtins.readFile ./project-host.json);
in
{
  networking.hostName = host.hostName;
  system.stateVersion = host.stateVersion;
  boot = {
    loader = host.bootLoader;
    initrd.systemd.enable = host.initrdSystemd;
    kernelParams = host.kernelParams;
    resumeDevice = host.resumeDevice;
  };
  services.xserver.videoDrivers = host.videoDrivers;
  hardware.graphics = {
    inherit (host.graphics) enable32Bit;
    extraPackages = map (name: pkgs.${name}) host.graphics.extraPackageNames;
    extraPackages32 = map (name: pkgs.pkgsi686Linux.${name}) host.graphics.extraPackageNames32;
  };
  hardware.nvidia = lib.mkIf (builtins.elem "nvidia" host.videoDrivers) host.nvidia;
  users.users.${host.username} = {
    isNormalUser = true;
    home = host.homeDirectory;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
  home-manager.users.${host.username}.programs.bash.shellAliases = {
    rebuild = lib.mkForce "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
    nix-check = lib.mkForce "nix flake check /etc/nixos";
  };
}

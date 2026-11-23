{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  useZswap = config.swapDevices != [ ] && !config.zramSwap.enable;
in

{
  # Hold Space during firmware startup to open the generation/recovery menu.
  boot.loader.timeout = 0;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Cache swap pages in compressed RAM before using the host's existing disk swap.
  # Configure supported parameters directly: the pinned zswap module still writes
  # a zpool parameter that this kernel no longer exposes.
  boot.kernelParams = lib.optionals useZswap [
    "zswap.enabled=1"
    "zswap.compressor=zstd"
    "zswap.max_pool_percent=20"
  ];
  boot.kernel.sysfs.module.zswap.parameters = lib.mkIf useZswap {
    enabled = true;
    compressor = "zstd";
    max_pool_percent = 20;
  };

  # Target application units only; Hyprland and session services use session.slice.
  systemd.oomd.enable = true;
  systemd.user.slices.app = {
    overrideStrategy = "asDropin";
    sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "40%";
      ManagedOOMMemoryPressureDurationSec = "10s";
      ManagedOOMSwap = "kill";
    };
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      warn-dirty = false;
      # Leave CPU and memory headroom for the graphical session during builds.
      max-jobs = lib.mkDefault 2;
      cores = lib.mkDefault 2;
    };
    registry.nixpkgs.flake = inputs.nixpkgs;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  environment.systemPackages = with pkgs; [
    android-tools
    git
    iw
    nano
  ];
}

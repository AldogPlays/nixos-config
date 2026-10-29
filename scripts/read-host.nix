{
  nixpkgs,
  configuration,
  username,
}:
let
  evaluated = import (nixpkgs + "/nixos") {
    configuration = builtins.toPath configuration;
    system = "x86_64-linux";
  };
  inherit (evaluated) config;
  inherit (evaluated.pkgs) lib;
  graphicsNames = [
    "intel-media-driver"
    "intel-vaapi-driver"
    "nvidia-vaapi-driver"
    "libvdpau-va-gl"
    "vpl-gpu-rt"
  ];
  identifyGraphics =
    packageSet: package:
    lib.findFirst (
      name: builtins.hasAttr name packageSet && packageSet.${name}.drvPath == package.drvPath
    ) null graphicsNames;
  # The shared hardware module supplies Mesa OpenCL on every adopted host.
  graphicsExtras = map (identifyGraphics evaluated.pkgs) (
    builtins.filter (
      package: package.outPath != evaluated.pkgs.mesa.opencl.outPath
    ) config.hardware.graphics.extraPackages
  );
  graphicsExtras32 = map (identifyGraphics evaluated.pkgs.pkgsi686Linux) config.hardware.graphics.extraPackages32;
in
{
  # Deliberate allowlist: never serialize users, password hashes, keys or tokens.
  inherit (config.networking) hostName;
  inherit (config.system) stateVersion;
  mutableUsers = config.users.mutableUsers;
  userIsNormal = config.users.users.${username}.isNormalUser or false;
  initrdSystemd = config.boot.initrd.systemd.enable;
  kernelParams = config.boot.kernelParams;
  resumeDevice = config.boot.resumeDevice;
  videoDrivers = config.services.xserver.videoDrivers;
  graphics = {
    inherit (config.hardware.graphics) enable32Bit;
    extraPackageNames = graphicsExtras;
    extraPackageNames32 = graphicsExtras32;
  };
  bootLoader = {
    systemd-boot = {
      inherit (config.boot.loader.systemd-boot) enable configurationLimit;
    };
    efi = {
      inherit (config.boot.loader.efi) canTouchEfiVariables efiSysMountPoint;
    };
    grub = {
      inherit (config.boot.loader.grub)
        enable
        devices
        efiSupport
        efiInstallAsRemovable
        enableCryptodisk
        useOSProber
        ;
    };
  };
  unsupportedBoot =
    lib.attrByPath [ "boot" "lanzaboote" "enable" ] false config
    || config.boot.loader.grub.mirroredBoots != [ ];
  nvidia = lib.optionalAttrs (builtins.elem "nvidia" config.services.xserver.videoDrivers) {
    inherit (config.hardware.nvidia) open branch;
    modesetting.enable = config.hardware.nvidia.modesetting.enable;
    powerManagement = {
      inherit (config.hardware.nvidia.powerManagement) enable finegrained;
    };
    prime = {
      inherit (config.hardware.nvidia.prime) nvidiaBusId intelBusId amdgpuBusId;
      offload = {
        inherit (config.hardware.nvidia.prime.offload) enable enableOffloadCmd;
      };
      sync.enable = config.hardware.nvidia.prime.sync.enable;
      reverseSync.enable = config.hardware.nvidia.prime.reverseSync.enable;
    };
  };
  unsupportedGraphics =
    builtins.elem null graphicsExtras
    || builtins.elem null graphicsExtras32
    || (
      config.hardware.graphics.enable
      && (
        config.hardware.graphics.package.drvPath != evaluated.pkgs.mesa.drvPath
        || (
          config.hardware.graphics.enable32Bit
          && config.hardware.graphics.package32.drvPath != evaluated.pkgs.pkgsi686Linux.mesa.drvPath
        )
      )
    )
    || (
      builtins.elem "nvidia" config.services.xserver.videoDrivers
      &&
        config.hardware.nvidia.package.drvPath
        != config.boot.kernelPackages.nvidiaPackages.${config.hardware.nvidia.branch}.drvPath
    );
}

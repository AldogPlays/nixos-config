{
  description = "Jeffrey's reproducible NixOS and Hyprland configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Keep fast-moving developer tools (notably Codex) newer than the OS base.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wlctl = {
      url = "github:aashish-thapa/wlctl/v0.1.10";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wiremix = {
      url = "github:AldogPlays/wiremix/codex/ui-match";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      home-manager,
      nixpkgs,
      nixpkgs-unstable,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      mkSystem =
        {
          modules,
          username ? "jeffreyc",
          homeDirectory ? "/home/${username}",
          homeStateVersion ? "26.05",
          themeSelection ? import ./theme/selection.nix,
          themeConfiguration ? {
            kind = "checkout";
            directory = "/home/${username}/Projects/nixos-config";
          },
        }:
        let
          desktopTheme = import ./theme/load.nix themeSelection;
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              pkgsUnstable
              desktopTheme
              themeConfiguration
              themeSelection
              ;
          };

          modules = modules ++ [
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                extraSpecialArgs = {
                  inherit
                    inputs
                    pkgsUnstable
                    desktopTheme
                    themeConfiguration
                    ;
                };
                users.${username} = {
                  imports = [ ./home/jeffreyc ];
                  home = {
                    inherit username homeDirectory;
                    stateVersion = homeStateVersion;
                  };
                };
              };
            }
          ];
        };
    in
    {
      nixosConfigurations.nixos = mkSystem { modules = [ ./hosts/nixos ]; };

      lib.mkPortableSystem =
        {
          hardwareModule,
          hostModule,
          username,
          homeDirectory,
          homeStateVersion ? "26.05",
          themeSelection ? import ./theme/selection.nix,
        }:
        mkSystem {
          inherit
            username
            homeDirectory
            homeStateVersion
            themeSelection
            ;
          themeConfiguration = {
            kind = "portable";
            directory = "/etc/nixos";
          };
          modules = [
            hardwareModule
            hostModule
            {
              # Keep the exact private project snapshot reachable after GC.
              environment.etc."nixos-project-source".source = inputs.self.outPath;
            }
            ./modules/nixos/core.nix
            ./modules/nixos/hardware.nix
            ./modules/nixos/hyprland.nix
          ];
        };

      apps.${system} = {
        bootstrap = {
          type = "app";
          meta.description = "Preview or adopt an installed x86-64 NixOS system";
          program = nixpkgs.lib.getExe (
            pkgs.callPackage ./packages/bootstrap.nix {
              projectSource = inputs.self.outPath;
              nixpkgsSource = nixpkgs.outPath;
            }
          );
        };

        instagram-reels-patch = {
          type = "app";
          meta.description = "Build the pinned Instagram clone without Home, Reels or messaging Blend controls";
          program = nixpkgs.lib.getExe (pkgs.callPackage ./packages/instagram-reels { });
        };
      };

      checks.${system} = {
        instagram-patch =
          pkgs.runCommand "instagram-patch-checks" { nativeBuildInputs = [ pkgs.python3 ]; }
            ''
              export PYTHONDONTWRITEBYTECODE=1
              mkdir -p packages/instagram-reels tests
              cp ${./packages/instagram-reels/patch.py} packages/instagram-reels/patch.py
              cp ${./tests/test_instagram_patch.py} tests/test_instagram_patch.py
              python3 -m unittest discover -s tests -p test_instagram_patch.py -v
              touch "$out"
            '';
        dolphin-place = pkgs.runCommand "dolphin-place-checks" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          export PYTHONDONTWRITEBYTECODE=1
          cp -r ${./scripts} scripts
          cp -r ${./tests} tests
          python3 -m unittest discover -s tests -p test_dolphin_place.py -v
          touch "$out"
        '';
        theme-menu = pkgs.runCommand "theme-menu-checks" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          export PYTHONDONTWRITEBYTECODE=1
          cp -r ${./scripts} scripts
          cp -r ${./tests} tests
          python3 -m unittest discover -s tests -p test_theme_menu.py -v
          touch "$out"
        '';
        screenshot-selector = pkgs.callPackage ./packages/slurp { };
        power-source-profile =
          pkgs.runCommand "power-source-profile-checks"
            {
              nativeBuildInputs = [ pkgs.python3 ];
            }
            ''
              export PYTHONDONTWRITEBYTECODE=1
              cp -r ${./scripts} scripts
              cp -r ${./tests} tests
              python3 -m unittest discover -s tests -p test_power_source_profile.py -v
              python3 -m unittest discover -s tests -p test_battery_charge.py -v
              touch "$out"
            '';
        workspace-wallpapers =
          pkgs.runCommand "workspace-wallpaper-checks"
            {
              nativeBuildInputs = [
                (pkgs.python3.withPackages (p: [ p.pillow ]))
                pkgs.lua
              ];
            }
            ''
              export PYTHONDONTWRITEBYTECODE=1
              cp -r ${./dotfiles} dotfiles
              cp -r ${./tests} tests
              python3 -m unittest discover -s tests -p test_workspace_wallpapers.py -v
              luac -p ${
                inputs.self.nixosConfigurations.nixos.config.home-manager.users.jeffreyc.xdg.configFile."hypr/hyprland.lua".source
              }
              lua tests/test_workspace_wallpapers.lua ${
                inputs.self.nixosConfigurations.nixos.config.home-manager.users.jeffreyc.xdg.configFile."hypr/hyprland.lua".source
              }
              touch "$out"
            '';

        bootstrap =
          pkgs.runCommand "bootstrap-checks"
            {
              nativeBuildInputs = [ pkgs.python3 ];
            }
            ''
              export PYTHONDONTWRITEBYTECODE=1
              cp -r ${./scripts} scripts
              cp -r ${./bootstrap} bootstrap
              cp -r ${./tests} tests
              python3 -m unittest discover -s tests -p test_bootstrap.py -v
              touch "$out"
            '';

        portable-hosts =
          let
            fixture =
              name: bios: driver: themeSelection:
              let
                data = {
                  username = "alex";
                  homeDirectory = "/home/alex";
                  homeStateVersion = "26.05";
                  hostName = name;
                  stateVersion = "25.11";
                  initrdSystemd = true;
                  kernelParams = [ ];
                  resumeDevice = "";
                  videoDrivers = [ driver ];
                  graphics = {
                    enable32Bit = name == "portable-intel";
                    extraPackageNames = if name == "portable-intel" then [ "intel-media-driver" ] else [ ];
                    extraPackageNames32 = [ ];
                  };
                  nvidia = {
                    open = true;
                    modesetting.enable = true;
                  };
                  bootLoader = {
                    systemd-boot.enable = !bios;
                    grub = {
                      enable = bios;
                      devices = [ "/dev/disk/by-id/fixture" ];
                    };
                    efi = {
                      canTouchEfiVariables = !bios;
                      efiSysMountPoint = "/efi";
                    };
                  };
                };
                hostJSON = builtins.toFile "project-host.json" (builtins.toJSON data);
                hostModule = builtins.toFile "fixture-host.nix" (
                  builtins.replaceStrings [ "./project-host.json" ] [ (toString hostJSON) ] (
                    builtins.readFile ./bootstrap/host.nix
                  )
                );
              in
              (inputs.self.lib.mkPortableSystem {
                inherit hostModule themeSelection;
                inherit (data) username homeDirectory homeStateVersion;
                hardwareModule = {
                  fileSystems = {
                    "/" = {
                      device = "/dev/disk/by-label/new-root";
                      fsType = "ext4";
                    };
                    "/efi" = {
                      device = "/dev/disk/by-label/new-efi";
                      fsType = "vfat";
                    };
                  };
                  boot.kernelModules = [ (if bios then "kvm-amd" else "kvm-intel") ];
                };
              }).config;
            intel = fixture "portable-intel" false "modesetting" (import ./theme/selection.nix);
            bios = fixture "portable-bios" true "modesetting" (import ./theme/selection.nix);
            nvidia = fixture "portable-nvidia" false "nvidia" (import ./theme/selection.nix);
            monochrome = fixture "portable-monochrome" false "modesetting" {
              preset = "monochrome";
              wallpaperMode = "color";
            };
            monochromeIdentity = builtins.fromJSON monochrome.environment.etc."desktop-theme.json".text;
            readFixture =
              extras:
              import ./scripts/read-host.nix {
                nixpkgs = nixpkgs.outPath;
                username = "alex";
                configuration = builtins.toFile "read-host-fixture.nix" ''
                  { pkgs, ... }: {
                    system.stateVersion = "25.11";
                    users.users.alex.isNormalUser = true;
                    boot.loader.systemd-boot.enable = true;
                    hardware.graphics = {
                      enable = true;
                      enable32Bit = true;
                      extraPackages = [ ${extras} ];
                      extraPackages32 = [ pkgs.pkgsi686Linux.intel-media-driver ];
                    };
                  }
                '';
              };
            readIntel = readFixture "pkgs.intel-media-driver";
            readMesa = readFixture "pkgs.mesa.opencl pkgs.intel-media-driver";
            readCustom = readFixture "pkgs.hello";
          in
          assert intel.fileSystems."/".device == "/dev/disk/by-label/new-root";
          assert intel.boot.loader.efi.efiSysMountPoint == "/efi";
          assert builtins.elem "kvm-intel" intel.boot.kernelModules;
          assert !(builtins.elem "kvm-amd" intel.boot.kernelModules);
          assert !(intel.users.users ? jeffreyc);
          assert intel.home-manager.users.alex.home.homeDirectory == "/home/alex";
          assert intel.system.stateVersion == "25.11";
          assert intel.hardware.graphics.enable32Bit;
          assert builtins.any (
            p: p.outPath == pkgs.intel-media-driver.outPath
          ) intel.hardware.graphics.extraPackages;
          assert builtins.any (
            p: p.outPath == pkgs.mesa.opencl.outPath
          ) intel.hardware.graphics.extraPackages;
          assert intel.environment.etc."nixos-project-source".source == inputs.self.outPath;
          assert bios.boot.loader.grub.enable && !bios.boot.loader.systemd-boot.enable;
          assert bios.boot.loader.grub.devices == [ "/dev/disk/by-id/fixture" ];
          assert bios.programs.steam.enable && bios.hardware.graphics.enable32Bit;
          assert nvidia.services.xserver.videoDrivers == [ "nvidia" ];
          assert nvidia.programs.steam.enable && nvidia.hardware.graphics.enable32Bit;
          assert readIntel.graphics.extraPackageNames == [ "intel-media-driver" ];
          assert readIntel.graphics.extraPackageNames32 == [ "intel-media-driver" ];
          assert !readIntel.unsupportedGraphics;
          assert readMesa.graphics.extraPackageNames == [ "intel-media-driver" ];
          assert !readMesa.unsupportedGraphics;
          assert readCustom.unsupportedGraphics;
          assert monochrome.home-manager.users.alex.gtk.colorScheme == "dark";
          assert monochromeIdentity.preset == "monochrome";
          assert monochromeIdentity.wallpaperMode == "color";
          assert monochromeIdentity.configuration.kind == "portable";
          pkgs.runCommand "portable-host-checks" { } ''
            # Force complete generation evaluation, including module assertions.
            echo ${builtins.unsafeDiscardStringContext intel.system.build.toplevel.drvPath} > "$out"
            echo ${builtins.unsafeDiscardStringContext bios.system.build.toplevel.drvPath} >> "$out"
            echo ${builtins.unsafeDiscardStringContext nvidia.system.build.toplevel.drvPath} >> "$out"
            echo ${builtins.unsafeDiscardStringContext monochrome.system.build.toplevel.drvPath} >> "$out"
          '';
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}

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

    snap-src = {
      url = "github:yumedots/snap";
      flake = false;
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
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgsUnstable; };

        modules = [
          ./hosts/nixos
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = { inherit inputs pkgsUnstable; };
              users.jeffreyc = import ./home/jeffreyc;
            };
          }
        ];
      };

      checks.${system}.workspace-wallpapers =
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
            python3 -m unittest discover -s tests -v
            luac -p ${
              inputs.self.nixosConfigurations.nixos.config.home-manager.users.jeffreyc.xdg.configFile."hypr/hyprland.lua".source
            }
            lua tests/test_workspace_wallpapers.lua ${
              inputs.self.nixosConfigurations.nixos.config.home-manager.users.jeffreyc.xdg.configFile."hypr/hyprland.lua".source
            }
            touch "$out"
          '';

      formatter.${system} = pkgs.nixfmt-tree;
    };
}

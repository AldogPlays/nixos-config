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

    hyprspace-src = {
      # Upstream's hyprpm compatibility pin for Hyprland 0.55.4, including Lua bindings.
      url = "github:KZDKM/Hyprspace/3624878a7b6c00dfa77e351438fa209df99ad81d";
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

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}

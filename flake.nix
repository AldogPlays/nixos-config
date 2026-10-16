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

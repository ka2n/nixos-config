{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    nixos-hardware = { url = "github:NixOS/nixos-hardware/master"; };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mdatp = {
      url = "github:NitorCreations/nix-mdatp";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    himmelblau = {
      url = "github:himmelblau-idm/himmelblau/stable-2.x";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    inputactions = {
      url = "github:taj-ny/InputActions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-hardware, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      overlay = import ./pkgs;
    in {
      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-unstable; };
        modules =
          [ { nixpkgs.overlays = [ overlay ]; } ./hosts/vm/configuration.nix ];
      };

      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-unstable; };
        modules = [
          { nixpkgs.overlays = [ overlay ]; }
          ./hosts/laptop/configuration.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-x1-13th-gen
        ];
      };

      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-unstable; };
        modules = [
          { nixpkgs.overlays = [ overlay ]; }
          inputs.disko.nixosModules.disko
          ./hosts/desktop/configuration.nix
        ];
      };
    };
}

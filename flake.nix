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
      url = "github:himmelblau-idm/himmelblau/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    inputactions = {
      # Pinned to Dec 2025 revision compatible with nixos-25.11's Hyprland
      url = "github:taj-ny/InputActions/2eb2a2450ddc85befb770c60d5baf9ced7d1197d";
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
    sops-nix = {
      url = "github:Mic92/sops-nix";
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
      overlay = import ./pkgs pkgs-unstable;
      configRevision = self.rev or self.dirtyRev or "dirty";
    in {
      devShells.${system} = import ./devShells.nix {
        inherit nixpkgs nixpkgs-unstable system;
      };

      nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-unstable configRevision; };
        modules = [
          { nixpkgs.overlays = [ overlay ]; }
          inputs.sops-nix.nixosModules.sops
          ./hosts/nixos-vm/configuration.nix
        ];
      };

      nixosConfigurations.wk2511058 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-unstable configRevision; };
        modules = [
          { nixpkgs.overlays = [ overlay ]; }
          inputs.sops-nix.nixosModules.sops
          ./hosts/wk2511058/configuration.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-x1-13th-gen
        ];
      };

      nixosConfigurations.junior = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-unstable configRevision; };
        modules = [
          { nixpkgs.overlays = [ overlay ]; }
          inputs.sops-nix.nixosModules.sops
          inputs.disko.nixosModules.disko
          ./hosts/junior/configuration.nix
        ];
      };
    };
}

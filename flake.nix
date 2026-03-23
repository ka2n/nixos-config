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
    # Pinned to v3.1.0 release
    # Don't follow nixpkgs to use Cachix cache (built against nixpkgs-25.05)
    himmelblau.url = "github:himmelblau-idm/himmelblau/3.1.0";
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
    river-classic.url = "git+https://codeberg.org/ka2n/river-classic";
    llm-agents.url = "github:numtide/llm-agents.nix";
    go-overlay.url = "github:purpleclay/go-overlay";
    playwright.url = "github:pietdevries94/playwright-web-flake";
    atuin.url = "github:atuinsh/atuin";
    gazelle-tui.url = "github:Zeus-Deus/gazelle-tui";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-hardware, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      configRevision = self.rev or self.dirtyRev or "dirty";

      llm-agents = inputs.llm-agents.packages.${system};

      # Common modules for all hosts
      commonModules = [
        {
          nixpkgs.overlays = [
            inputs.go-overlay.overlays.default
            (import ./pkgs pkgs-unstable llm-agents)
          ];
        }
        inputs.sops-nix.nixosModules.sops
      ];
    in {
      devShells.${system} = import ./devShells.nix {
        inherit nixpkgs nixpkgs-unstable system;
        playwright = inputs.playwright.packages.${system};
      };

      templates.default = {
        path = ./templates/default;
        description = "General web development environment with Node.js, Playwright, and Prisma";
      };

      nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs pkgs-unstable configRevision llm-agents; };
        modules = commonModules ++ [
          { nixpkgs.hostPlatform = system; }
          ./hosts/nixos-vm/configuration.nix
        ];
      };

      nixosConfigurations.wk2511058 = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs pkgs-unstable configRevision llm-agents; };
        modules = commonModules ++ [
          { nixpkgs.hostPlatform = system; }
          ./hosts/wk2511058/configuration.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-x1-13th-gen
        ];
      };

      nixosConfigurations.junior = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs pkgs-unstable configRevision llm-agents; };
        modules = commonModules ++ [
          { nixpkgs.hostPlatform = system; }
          inputs.disko.nixosModules.disko
          ./hosts/junior/configuration.nix
        ];
      };
    };
}

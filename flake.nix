{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
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
    # Keep upstream nixpkgs for the Himmelblau Cachix binaries.
    himmelblau.url = "github:himmelblau-idm/himmelblau/4.0.8";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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
    # Don't follow nixpkgs: llm-agents pins specific nixpkgs for package compat.
    llm-agents.url = "github:numtide/llm-agents.nix";
    go-overlay = {
      url = "github:purpleclay/go-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    playwright = {
      url = "github:pietdevries94/playwright-web-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    atuin = {
      url = "github:atuinsh/atuin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gazelle-tui = {
      url = "github:Zeus-Deus/gazelle-tui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    miru = {
      url = "github:ka2n/miru";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-hardware, home-manager, ...
    }@inputs:
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
            inputs.claude-desktop.overlays.default
            # aaddrick/claude-desktop-debian#920: 2.19675.1's claude-native
            # binding needs libpipewire, but upstream only lists pipewire in
            # runtimeDependencies, so autoPatchelf fails. Drop once fixed.
            (final: prev: {
              claude-desktop = prev.claude-desktop.overrideAttrs
                (old: { buildInputs = old.buildInputs ++ [ final.pipewire ]; });
            })
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
        description =
          "General web development environment with Node.js, Playwright, and Prisma";
      };

      nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs pkgs-unstable configRevision llm-agents;
        };
        modules = commonModules ++ [
          { nixpkgs.hostPlatform = system; }
          ./hosts/nixos-vm/configuration.nix
        ];
      };

      nixosConfigurations.wk2511058 = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs pkgs-unstable configRevision llm-agents;
        };
        modules = commonModules ++ [
          { nixpkgs.hostPlatform = system; }
          inputs.himmelblau.nixosModules.himmelblau
          ./hosts/wk2511058/configuration.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-x1-13th-gen
        ];
      };

      nixosConfigurations.junior = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs pkgs-unstable configRevision llm-agents;
        };
        modules = commonModules ++ [
          { nixpkgs.hostPlatform = system; }
          inputs.disko.nixosModules.disko
          ./hosts/junior/configuration.nix
        ];
      };
    };
}

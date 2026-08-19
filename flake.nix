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
    # Pinned to 3.1.12 — carries the #1206 resume/boot deadlock root fix from
    # 3.1.9 (resolver releases the DB lock before the offline-auth fallback),
    # which let upstream revert the NetworkManager dispatcher workaround (that
    # script is now deleted; see modules/himmelblau), the 3.1.10 NSS shadow fix
    # (GDM stops hiding Himmelblau users as "locked"), the #1344 NSS rate-limit
    # fix (local-only names skip the Entra GetCredentialType probe), PCR7-free
    # HSM PIN sealing (Secure Boot cert update safe) and automatic MFA fallback.
    # 3.1.11 is a security release: PamChangeAuthToken now binds PIN changes to
    # the calling peer's UID (GHSA-6gp8-pp9v-gx45), subuid/subgid names are
    # sanitized (GHSA-x259-23ph-65m5), RFC2307 uid/gidNumber inside systemd's
    # DynamicUser range 61184-65519 are rejected (ours is 1001, unaffected),
    # the Office 365 URL handler only trusts real M365 origins
    # (GHSA-4f5j-9xgm-8pvr), and pam_allow_groups denials are terminal in the
    # PAM account phase (we don't set pam_allow_groups).
    # 3.1.12 keeps a failed IdP password change re-promptable instead of
    # discarding the old password, returns `ok` (not done) from the PAM account
    # check so local modules stay reachable, skips Entra-only post-auth work
    # (Kerberos cache, profile photo) under OIDC, and adds CacheDirectory to the
    # himmelblaud-tasks sandbox — which retires our ReadWritePaths mkForce.
    # Don't follow nixpkgs to use Cachix cache (built against nixpkgs-unstable).
    himmelblau.url = "github:himmelblau-idm/himmelblau/3.1.12";
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

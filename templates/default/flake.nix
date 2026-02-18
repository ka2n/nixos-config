{
  description = "Web development environment with Node.js, Playwright, and Prisma";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    playwright.url = "github:pietdevries94/playwright-web-flake";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, playwright }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages =
          [
            # Node.js and package managers
            pkgs.nodejs_22
            pkgs.nodePackages.pnpm
            pkgs.nodePackages.npm

            # Playwright
            playwright.packages.${system}.playwright-test

            # Database and development tools
            pkgs.jq
            pkgs.openssl.dev
            pkgs.lsof

            # Web development tools
            pkgs.curl
            pkgs.wget
            pkgs.entr
            pkgs.watchexec
            pkgs.tree
            pkgs.netcat
            pkgs.sqlite
            pkgs.stripe-cli

            # Prisma
            pkgs-unstable.prisma-engines_7
          ];

        shellHook = ''
          # Playwright configuration
          export PLAYWRIGHT_BROWSERS_PATH=${playwright.packages.${system}.playwright-driver.browsers}
          export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
          export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true

          # Prisma configuration
          export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig"
          export PRISMA_SCHEMA_ENGINE_BINARY="${pkgs-unstable.prisma-engines_7}/bin/schema-engine"
          export PRISMA_QUERY_ENGINE_BINARY="${pkgs-unstable.prisma-engines_7}/bin/query-engine"
          export PRISMA_QUERY_ENGINE_LIBRARY="${pkgs-unstable.prisma-engines_7}/lib/libquery_engine.node"
          export PRISMA_FMT_BINARY="${pkgs-unstable.prisma-engines_7}/bin/prisma-fmt"

          echo "Development environment loaded!"
          echo "Node.js: $(node --version)"
          echo "npm: $(npm --version)"
          echo "pnpm: $(pnpm --version)"
        '';
      };
    };
}

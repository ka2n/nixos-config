{ nixpkgs, nixpkgs-unstable, system, playwright }:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  pkgs-unstable = import nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in {
  # 通常利用てんこ盛りパック
  # Usage: nix develop ~/nixos-config
  default = pkgs.mkShell {
    packages =
      [
        # Playwright (via playwright-web-flake)
        playwright.playwright-test

        # Node.js tools
        pkgs.jq
        pkgs.volta
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
      export PLAYWRIGHT_BROWSERS_PATH=${playwright.playwright-driver.browsers}
      export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
      export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true

      # Volta configuration
      export VOLTA_HOME="$HOME/.volta"
      export PATH="$VOLTA_HOME/bin:$PATH"
      export VOLTA_FEATURE_PNPM=1

      # NixOS compatibility for Volta-installed binaries
      export NIX_LD_LIBRARY_PATH="${
        pkgs.lib.makeLibraryPath (with pkgs; [ stdenv.cc.cc openssl ])
      }"
      export NIX_LD="${
        pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker"
      }"

      # Prisma configuration
      export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig"
      export PRISMA_SCHEMA_ENGINE_BINARY="${pkgs-unstable.prisma-engines_7}/bin/schema-engine"
      export PRISMA_QUERY_ENGINE_BINARY="${pkgs-unstable.prisma-engines_7}/bin/query-engine"
      export PRISMA_QUERY_ENGINE_LIBRARY="${pkgs-unstable.prisma-engines_7}/lib/libquery_engine.node"
      export PRISMA_FMT_BINARY="${pkgs-unstable.prisma-engines_7}/bin/prisma-fmt"
    '';
  };
}

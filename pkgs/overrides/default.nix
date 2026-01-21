# Temporary overrides waiting for upstream nixpkgs updates
# Remove entries when nixpkgs-unstable catches up
{ pkgs-unstable }:

{
  # claude-code 2.1.14 (nixpkgs-unstable has 2.0.76)
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/cl/claude-code/package.nix
  claude-code = pkgs-unstable.buildNpmPackage {
    pname = "claude-code";
    version = "2.1.14";

    src = pkgs-unstable.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.14.tgz";
      hash = "sha256-QiBvRm1iMtO3mmlu5a/aKaJzcAQxeBW7yLK4R4k6SU0=";
    };

    npmDepsHash = "sha256-PIhayi4wNoP4XxWpEIH7/Ycq1mBAMcE4vDuLCTW7/bE=";

    postPatch = ''
      cp ${./claude-code-package-lock.json} package-lock.json
    '';

    dontNpmBuild = true;

    env.AUTHORIZED = "1";

    postInstall = ''
      wrapProgram $out/bin/claude \
        --set DISABLE_AUTOUPDATER 1 \
        --unset DEV
    '';

    meta = {
      description = "Agentic coding tool that lives in your terminal";
      homepage = "https://github.com/anthropics/claude-code";
      license = pkgs-unstable.lib.licenses.unfree;
      mainProgram = "claude";
    };
  };
}

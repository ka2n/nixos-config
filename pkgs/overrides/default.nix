# Temporary overrides waiting for upstream nixpkgs updates
# Remove entries when nixpkgs-unstable catches up
{ pkgs-unstable }:

{
  # claude-code 2.1.30 (nixpkgs-unstable has 2.0.76)
  # Binary distribution from official GCS bucket
  claude-code = pkgs-unstable.stdenv.mkDerivation {
    pname = "claude-code";
    version = "2.1.30";

    src = pkgs-unstable.fetchurl {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/2.1.30/linux-x64/claude";
      hash = "sha256-rajxz5Jyll04sQ8a22zqiF5iHIP357sjMAjHIfQ/rVQ=";
    };

    nativeBuildInputs = [ pkgs-unstable.makeWrapper ];

    dontUnpack = true;
    dontStrip = true;
    dontPatchELF = true;

    # Disable auto-updates, installation method warning, telemetry https://github.com/anthropics/claude-code/issues/15592
    installPhase = ''
      install -Dm755 $src $out/bin/.claude-unwrapped
      makeWrapper $out/bin/.claude-unwrapped $out/bin/claude \
        --set DISABLE_AUTOUPDATER 1 \
        --set DISABLE_INSTALLATION_CHECKS 1 \
        --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
        --set DISABLE_TELEMETRY 1 \
    '';

    meta = {
      description = "Agentic coding tool that lives in your terminal";
      homepage = "https://github.com/anthropics/claude-code";
      license = pkgs-unstable.lib.licenses.unfree;
      mainProgram = "claude";
    };
  };
}

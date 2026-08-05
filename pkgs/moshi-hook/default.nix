{
  lib,
  stdenvNoCC,
  fetchurl,
}:

# moshi-hook: host-side daemon + CLI that bridges AI coding agents (Claude Code,
# Codex, ...) to the Moshi mobile app. Ships as a statically-linked Go binary,
# so no autoPatchelf / buildInputs are needed.
#
# Upstream distributes prebuilt tarballs from a CDN (no public source repo):
#   https://cdn.getmoshi.app/hook/<version>/moshi-hook_<OS>_<ARCH>.tar.gz
# Latest version:  curl -fsSL https://cdn.getmoshi.app/hook/latest/version.txt
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "moshi-hook";
  version = "0.2.73";

  src =
    let
      arch = {
        x86_64-linux = "Linux_x86_64";
        aarch64-linux = "Linux_arm64";
        x86_64-darwin = "Darwin_x86_64";
        aarch64-darwin = "Darwin_arm64";
      }.${stdenvNoCC.hostPlatform.system}
        or (throw "moshi-hook: unsupported system ${stdenvNoCC.hostPlatform.system}");
      hash = {
        x86_64-linux = "sha256-oeau2bA5dme1EGAqJ2xSkBbPSTpvhHqkfDdl5afkMtQ=";
        aarch64-linux = "sha256-L0k+kjBXpM1NhdNhj7YTCdDUm91VCsKmg4GTQx6wulk=";
        x86_64-darwin = "sha256-EYfeUyXFnnQ5cb+inEG3WpBxVYN/21xANZylGsoSkIE=";
        aarch64-darwin = "sha256-O4M0WLXKjCYZ8Cdtvprxx77sQDYqcEMD3iR4JFHxDYY=";
      }.${stdenvNoCC.hostPlatform.system};
    in
    fetchurl {
      url = "https://cdn.getmoshi.app/hook/v${finalAttrs.version}/moshi-hook_${arch}.tar.gz";
      inherit hash;
    };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 moshi-hook $out/bin/moshi-hook
    # The upstream installer also exposes a `moshi` alias for the same binary.
    ln -s moshi-hook $out/bin/moshi

    install -Dm644 README.md -t $out/share/doc/moshi-hook
    cp -r docs $out/share/doc/moshi-hook/

    runHook postInstall
  '';

  meta = {
    description = "Host-side daemon and CLI bridging AI coding agents to the Moshi mobile app";
    homepage = "https://getmoshi.app/docs/hooks";
    license = lib.licenses.unfree; # proprietary, distributed as prebuilt binary
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "moshi-hook";
  };
})

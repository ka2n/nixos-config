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
  version = "0.2.41";

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
        x86_64-linux = "sha256-n1J7gbCDLCPIvc9e7qtWY56hnxhc7Ya4B0l3sjmOEPo=";
        aarch64-linux = "sha256-4yK6Ye+WXGu64rmOURod4zByfIJRUooS27m2Sh1hPxo=";
        x86_64-darwin = "sha256-XhVpFcpcZqt6z4r+O462c94gBfplwpnL+NloQWM+2cI=";
        aarch64-darwin = "sha256-p9p2Pu9RCHXFRxasfmEcoPP68hCnXCDzrsmCGxmTxgo=";
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

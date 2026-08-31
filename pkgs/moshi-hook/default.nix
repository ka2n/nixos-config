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
  version = "0.3.14";

  # One entry per system: the upstream archive's OS_ARCH suffix and its hash.
  # Kept in a single attrset (not two parallel maps) so scripts/update.sh cannot
  # rewrite the arch suffix with a hash -- see the sed in that script.
  src =
    let
      sources = {
        x86_64-linux = { arch = "Linux_x86_64"; hash = "sha256-kbH3T7+DHSTqvX6S+jpByHNrNc7p0mQ3jZrtK6TeWgI="; };
        aarch64-linux = { arch = "Linux_arm64"; hash = "sha256-WGL9YrW2SoMMGREGrpVfEo4JklbR/EK3RNzDgFP5pIE="; };
        x86_64-darwin = { arch = "Darwin_x86_64"; hash = "sha256-Syh+dWckJCELQRFbB5TzQEBf/I2A85TaaEIDWc8/5+k="; };
        aarch64-darwin = { arch = "Darwin_arm64"; hash = "sha256-mnwYJwbPmxNpg4MGcGsPnd+aH18D/DmzSt2s70yY6ws="; };
      };
      source = sources.${stdenvNoCC.hostPlatform.system}
        or (throw "moshi-hook: unsupported system ${stdenvNoCC.hostPlatform.system}");
    in
    fetchurl {
      url = "https://cdn.getmoshi.app/hook/v${finalAttrs.version}/moshi-hook_${source.arch}.tar.gz";
      inherit (source) hash;
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

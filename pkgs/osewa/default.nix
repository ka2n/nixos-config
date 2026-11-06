{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.1.2";
  sources = {
    x86_64-linux = {
      asset = "osewa-linux-amd64.gz";
      hash = "sha256-kNoTOkcAW7nri/ikGyb3xXMi9rkp3oGbldGks5kluac=";
    };
    aarch64-linux = {
      asset = "osewa-linux-arm64.gz";
      hash = "sha256-Hi5QO1n4O8ARFlTZG4KR3RRtS96pBPqBAYQmht81YLw=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "osewa: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "osewa";
  inherit version;

  # Prebuilt: libghostty-vt needs a Zig build.
  src = fetchurl {
    url = "https://github.com/rjyo/osewa/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    gunzip -c $src > $out/bin/osewa
    chmod 755 $out/bin/osewa
    runHook postInstall
  '';

  meta = with lib; {
    description = "Persistent remote terminals over QUIC and TLS WebSocket, built on libghostty-vt";
    homepage = "https://github.com/rjyo/osewa";
    license = licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "osewa";
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}

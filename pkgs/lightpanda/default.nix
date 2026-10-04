{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lightpanda";
  version = "1.0.0";

  # Prebuilt: the Zig + V8 source build is too heavy.
  src = fetchurl {
    url = "https://github.com/lightpanda-io/browser/releases/download/${version}/lightpanda-x86_64-linux";
    hash = "sha256-qlpLjtU9Hjizxz9bJkfQqEqC5nRFV/RfmpyFhYqgMcM=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/lightpanda
    wrapProgram $out/bin/lightpanda --set-default LIGHTPANDA_DISABLE_TELEMETRY true
    runHook postInstall
  '';

  meta = with lib; {
    description = "Headless browser designed for AI agents and automation";
    homepage = "https://lightpanda.io";
    license = licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "lightpanda";
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}

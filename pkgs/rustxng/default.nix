{ lib, stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation rec {
  pname = "rustxng";
  version = "0.26.0";

  src = fetchurl {
    url = "https://github.com/sahenjp/RustXNG/releases/download/v${version}/rustxng-v${version}-x86_64-unknown-linux-musl";
    hash = "sha256-JQx18rtiPJkGUIewbUBVDNgCtIx62iZeLXRIu/HX+Dk=";
  };

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/rustxng
    runHook postInstall
  '';

  meta = with lib; {
    description = "Self-hosted metasearch and grounding engine for AI agents";
    homepage = "https://github.com/sahenjp/RustXNG";
    license = licenses.agpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "rustxng";
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}

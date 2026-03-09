{
  lib,
  stdenvNoCC,
  fetchzip,
  autoPatchelfHook,
}:

stdenvNoCC.mkDerivation rec {
  pname = "mo";
  version = "0.16.0";

  src = fetchzip {
    url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_linux_amd64.tar.gz";
    hash = "sha256-NSyw3rUdTtzK9glxeBQdIqA85nyfc4yXSG0kGmacDM8=";
    stripRoot = false;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    install -Dm755 mo $out/bin/mo
  '';

  meta = with lib; {
    description = "Markdown opener - display Markdown in browser with live-reload";
    homepage = "https://github.com/k1LoW/mo";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "mo";
  };
}

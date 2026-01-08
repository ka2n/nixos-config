{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "alma";
  version = "0.0.191";

  src = fetchurl {
    url = "https://github.com/yetone/alma-releases/releases/download/v${version}/alma-${version}-linux-x86_64.AppImage";
    hash = "sha256-qLCSaKsAs1QJzF5/EOt/MzdlwNrhKHnam+3F2GCAYbs=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    # Install desktop file
    install -Dm444 ${appimageContents}/alma.desktop $out/share/applications/alma.desktop
    substituteInPlace $out/share/applications/alma.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox' "Exec=${pname}"

    # Install icons
    for size in 16 32 48 64 128 256 512 1024; do
      icon="${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/alma.png"
      if [ -f "$icon" ]; then
        install -Dm444 "$icon" "$out/share/icons/hicolor/''${size}x''${size}/apps/alma.png"
      fi
    done
  '';

  meta = with lib; {
    description = "Alma - AI-powered desktop application";
    homepage = "https://alma.now";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "alma";
  };
}

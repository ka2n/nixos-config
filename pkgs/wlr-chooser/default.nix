{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, makeWrapper
, wayland
, libxkbcommon
, libgbm
, libglvnd
, fontconfig
}:

rustPlatform.buildRustPackage rec {
  pname = "wlr-chooser";
  version = "1.11.1";

  src = fetchFromGitHub {
    owner = "sjourdois";
    repo = "wlr-utils";
    rev = "v${version}";
    hash = "sha256-AVlZpmUA73UcZjLALHKEz+AhGP6MwqmHgAdamENosTE=";
  };

  cargoHash = "sha256-NaBFMTTlgEkiVtWbHQCuNUmmCPLZc7088AsTwbzSG5o=";
  cargoBuildFlags = [ "-p" "wlr-chooser" ];
  cargoTestFlags = [ "-p" "wlr-chooser" ];

  nativeBuildInputs = [ pkg-config makeWrapper ];
  buildInputs = [ wayland libxkbcommon libgbm ];

  postFixup = ''
    for binary in $out/bin/*; do
      wrapProgram "$binary" \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ wayland libxkbcommon libglvnd fontconfig ]}
    done
  '';

  meta = {
    description = "Wayland screen sharing picker with live window and monitor previews";
    homepage = "https://github.com/sjourdois/wlr-utils";
    license = with lib.licenses; [ mit asl20 ];
    platforms = lib.platforms.linux;
    mainProgram = "wlr-chooser";
  };
}

{ lib
, stdenv
, fetchFromGitHub
, rustPlatform
, cargo-c
, pkg-config
, libxkbcommon
}:

rustPlatform.buildRustPackage rec {
  pname = "libcskk";
  version = "3.1.1";

  src = fetchFromGitHub {
    owner = "naokiri";
    repo = "cskk";
    rev = "v${version}";
    hash = "sha256-ooAfyoHpFoMiF0ZpvasW72Xk5BZ/t3qEGxRX8keWFuA=";
  };

  cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  nativeBuildInputs = [
    cargo-c
    pkg-config
  ];

  buildInputs = [
    libxkbcommon
  ];

  buildPhase = ''
    runHook preBuild
    cargo cbuild --release --prefix=$out
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cargo cinstall --release --prefix=$out
    runHook postInstall
  '';

  meta = with lib; {
    description = "SKK (Simple Kana to Kanji conversion) library";
    homepage = "https://github.com/naokiri/cskk";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}

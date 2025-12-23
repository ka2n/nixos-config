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
  version = "3.2.0";

  src = fetchFromGitHub {
    owner = "naokiri";
    repo = "cskk";
    rev = "v${version}";
    hash = "sha256-lhLNtSmD5XiG0U6TLWgN+YA/f7UJ/RyHoe5vq5OopuI=";
  };

  cargoHash = "sha256-XWPeqQ3dC73Hp+TTPdLJtvF0hQ+uI82xfY7DxAXO1gA=";

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

    # Install assets (rules) to share/libcskk
    mkdir -p $out/share/libcskk
    cp -r assets/* $out/share/libcskk/
    runHook postInstall
  '';

  meta = with lib; {
    description = "SKK (Simple Kana to Kanji conversion) library";
    homepage = "https://github.com/naokiri/cskk";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}

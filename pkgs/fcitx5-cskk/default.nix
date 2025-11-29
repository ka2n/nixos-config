{ lib
, stdenv
, fetchFromGitHub
, cmake
, extra-cmake-modules
, pkg-config
, gettext
, fcitx5
, fcitx5-qt
, qtbase
, qtdeclarative
, libcskk
, wrapQtAppsHook
}:

stdenv.mkDerivation rec {
  pname = "fcitx5-cskk";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "fcitx";
    repo = "fcitx5-cskk";
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
    pkg-config
    gettext
    wrapQtAppsHook
  ];

  buildInputs = [
    fcitx5
    fcitx5-qt
    qtbase
    qtdeclarative
    libcskk
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
  ];

  meta = with lib; {
    description = "Fcitx5 wrapper for libcskk";
    homepage = "https://github.com/fcitx/fcitx5-cskk";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}

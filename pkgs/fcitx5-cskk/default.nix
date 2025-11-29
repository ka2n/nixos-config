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

stdenv.mkDerivation {
  pname = "fcitx5-cskk";
  version = "unstable-2024-12-15";

  src = fetchFromGitHub {
    owner = "fcitx";
    repo = "fcitx5-cskk";
    rev = "7ea513375d5412b37ab0251476f792d2467547e5";
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

{ lib
, stdenv
, fetchFromGitHub
, cmake
, extra-cmake-modules
, pkg-config
, gettext
, fcitx5
, libcskk
}:

stdenv.mkDerivation {
  pname = "fcitx5-cskk";
  version = "unstable-2024-12-15";

  src = fetchFromGitHub {
    owner = "fcitx";
    repo = "fcitx5-cskk";
    rev = "7ea513375d5412b37ab0251476f792d2467547e5";
    hash = "sha256-ooAfyoHpFoMiF0ZpvasW72Xk5BZ/t3qEGxRX8keWFuA=";
  };

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
    pkg-config
    gettext
  ];

  buildInputs = [
    fcitx5
    libcskk
  ];

  cmakeFlags = [
    (lib.cmakeBool "ENABLE_QT" false)
  ];

  dontWrapQtApps = true;

  meta = with lib; {
    description = "Fcitx5 wrapper for libcskk";
    homepage = "https://github.com/fcitx/fcitx5-cskk";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}

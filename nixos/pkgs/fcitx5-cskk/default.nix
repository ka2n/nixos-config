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
, wrapQtAppsHook
, libcskk
}:

let
  majorVersion = lib.versions.major qtbase.version;
in
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
    wrapQtAppsHook
  ];

  buildInputs = [
    fcitx5
    fcitx5-qt
    qtbase
    libcskk
  ];

  cmakeFlags = [
    (lib.cmakeBool "ENABLE_QT" true)
    (lib.cmakeBool "USE_QT6" (majorVersion == "6"))
  ];

  # Link libcskk's share directory (contains rules) into the output
  # so that fcitx5-with-addons can find the rules via XDG_DATA_DIRS
  postInstall = ''
    mkdir -p $out/share
    ln -s ${libcskk}/share/libcskk $out/share/libcskk
  '';

  meta = with lib; {
    description = "Fcitx5 wrapper for libcskk";
    homepage = "https://github.com/fcitx/fcitx5-cskk";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}

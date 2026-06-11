{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  cli11,
  kdePackages,
}:

stdenv.mkDerivation {
  pname = "inputactions-ctl";
  version = "0.9.0.0";

  src = fetchFromGitHub {
    owner = "InputActions";
    repo = "ctl";
    rev = "7ced2a43488b3fd810619e51aeca5d188ed583a8";
    hash = "sha256-TAdVHlU/954FaqXOkC5rF6X2P7pOm3S2mgr73hpl/Fw=";
  };

  nativeBuildInputs = [
    cmake
    kdePackages.extra-cmake-modules
    kdePackages.wrapQtAppsHook
  ];

  buildInputs = [
    cli11
    kdePackages.qttools
  ];

  meta = with lib; {
    description = "InputActions control tool";
    homepage = "https://github.com/InputActions/ctl";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}

{
  lib,
  fetchFromGitHub,
  cmake,
  extra-cmake-modules,
  hyprlandPlugins,
  kdePackages,
  libevdev,
  pkg-config,
  yaml-cpp,
}:

hyprlandPlugins.mkHyprlandPlugin rec {
  pluginName = "inputactions_hyprland";
  version = "0.8.3";

  src = fetchFromGitHub {
    owner = "taj-ny";
    repo = "InputActions";
    rev = "v${version}";
    hash = "sha256-1z1y72yGKxK816M9J41+4VvKey6jwZq2Lqe5VXlwjkw=";
  };

  dontWrapQtApps = true;

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
    pkg-config
  ];

  buildInputs = [
    kdePackages.qtbase
    libevdev
    yaml-cpp
  ];

  cmakeFlags = [
    "-DINPUTACTIONS_BUILD_HYPRLAND=ON"
  ];

  meta = with lib; {
    description = "Custom mouse and touchpad gestures for Hyprland (easystroke alternative)";
    homepage = "https://github.com/taj-ny/InputActions";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}

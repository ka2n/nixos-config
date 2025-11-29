final: prev: {
  libcskk = final.callPackage ./libcskk { };
  fcitx5-cskk = final.callPackage ./fcitx5-cskk {
    inherit (final) libcskk fcitx5;
    inherit (final.qt6) qtbase wrapQtAppsHook;
    inherit (final.kdePackages) fcitx5-qt;
  };
}

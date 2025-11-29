final: prev: {
  libcskk = final.callPackage ./libcskk { };
  fcitx5-cskk = final.callPackage ./fcitx5-cskk {
    inherit (final) libcskk;
  };
}

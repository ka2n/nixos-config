{ stdenv, zig }:

stdenv.mkDerivation {
  pname = "fake-os-release";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ zig ];

  buildPhase = ''
    export HOME=$TMPDIR
    zig build-lib -dynamic -lc -O ReleaseFast \
      --name fake-os-release \
      fake-os-release.zig
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp libfake-os-release.so $out/lib/
  '';

  meta = {
    description = "LD_PRELOAD library to fake /etc/os-release for Intune (Zig)";
  };
}

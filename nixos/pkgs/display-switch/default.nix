{ lib
, fetchFromGitHub
, rustPlatform
, pkg-config
, libusb1
, udev
}:

rustPlatform.buildRustPackage rec {
  pname = "display-switch";
  version = "1.4.1";

  src = fetchFromGitHub {
    owner = "haimgel";
    repo = "display-switch";
    rev = version;
    hash = "sha256-zHm09av/t4QxtwrSkGTtA4JWqHaVZ76Qibd86les6xQ=";
  };

  cargoHash = "sha256-dVrctqemTcGau+zCUyCoOZC8xHSbCbTMp5RtK4n5FyQ=";

  postPatch = ''
    rm -f rust-toolchain rust-toolchain.toml
  '';

  doCheck = false;

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libusb1
    udev
  ];

  meta = with lib; {
    description = "Utility to switch monitor inputs via DDC/CI and USB control";
    homepage = "https://github.com/haimgel/display-switch";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}

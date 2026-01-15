{
  lib,
  stdenv,
  fetchgit,
  cmake,
  pkg-config,
  qt6,
  yaml-cpp,
  libevdev,
  libinput,
  systemd,
  wayland,
  wayland-scanner,
  extra-cmake-modules,
  cli11,
}:

stdenv.mkDerivation rec {
  pname = "inputactions-standalone";
  version = "unstable-2026-01-06";

  src = fetchgit {
    url = "https://github.com/taj-ny/InputActions";
    rev = "7ffc5b6c930031b9bded124a12651ffb452aa7ce"; # HEAD with standalone support
    hash = "sha256-VxGCzqQopdqFEOos/6HAyLwPwy7wIEcq/iTHEkBnW+Y=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
    wayland-scanner
    extra-cmake-modules
  ];

  buildInputs = [
    qt6.qtbase
    yaml-cpp
    libevdev
    libinput
    systemd
    wayland
    cli11
  ];

  cmakeFlags = [
    "-DINPUTACTIONS_BUILD_STANDALONE=ON"
    "-DINPUTACTIONS_BUILD_CTL=ON"
    "-DINPUTACTIONS_SYSTEMD=OFF" # We'll create our own user service
  ];

  # Create systemd user service
  postInstall = ''
    mkdir -p $out/lib/systemd/user
    cat > $out/lib/systemd/user/inputactionsd.service << EOF
    [Unit]
    Description=InputActions Daemon
    PartOf=graphical-session.target
    After=graphical-session.target

    [Service]
    Type=simple
    ExecStart=$out/bin/inputactionsd
    Restart=on-failure
    RestartSec=5s

    [Install]
    WantedBy=graphical-session.target
    EOF
  '';

  meta = with lib; {
    description = "Mouse and touchpad gestures for Wayland compositors (standalone version)";
    homepage = "https://inputactions.org";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = [];
  };
}

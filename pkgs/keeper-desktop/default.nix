{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  xorg,
  libsecret,
  pcsclite,
  vips,
}:

stdenv.mkDerivation rec {
  pname = "keeper-desktop";
  version = "17.4.1";

  src = fetchurl {
    url = "https://www.keepersecurity.com/desktop_electron/Linux/repo/deb/keeperpasswordmanager_${version}_amd64.deb";
    sha256 = "0srl6zg4v8x0hvibgnjn23w26ffhya9nwqxpkyksprsg0yjpzx2w";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # Ignore musl-specific libraries that won't work on glibc systems
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemd
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    libsecret
    pcsclite
    vips
  ];

  unpackPhase = ''
    # Extract data.tar from deb, then extract with --no-same-permissions to avoid suid issues
    ar x $src
    tar --no-same-permissions -xf data.tar.*
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -r usr/lib/keeperpasswordmanager $out/lib/

    # Remove the suid chrome-sandbox (not needed with user namespaces)
    rm -f $out/lib/keeperpasswordmanager/chrome-sandbox

    mkdir -p $out/bin
    makeWrapper $out/lib/keeperpasswordmanager/keeperpasswordmanager $out/bin/keeper-desktop \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --add-flags "--no-sandbox"

    mkdir -p $out/share/applications
    cp usr/share/applications/keeperpasswordmanager.desktop $out/share/applications/keeper-desktop.desktop
    substituteInPlace $out/share/applications/keeper-desktop.desktop \
      --replace-fail 'Exec=keeperpasswordmanager' "Exec=$out/bin/keeper-desktop"

    mkdir -p $out/share/pixmaps
    cp usr/share/pixmaps/keeperpasswordmanager.png $out/share/pixmaps/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Keeper Password Manager desktop application";
    homepage = "https://www.keepersecurity.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "keeper-desktop";
  };
}

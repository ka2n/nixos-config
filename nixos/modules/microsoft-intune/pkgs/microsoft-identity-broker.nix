{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  dbus,
  libuuid,
  curlMinimal,
  openssl_3,
  xorg,
  webkitgtk_4_1,
  gtk3,
  zlib,
  pango,
  harfbuzz,
  atk,
  cairo,
  gdk-pixbuf,
  libsoup_3,
  libsecret,
  glib,
  p11-kit,
}:

stdenv.mkDerivation rec {
  pname = "microsoft-identity-broker";
  version = "2.0.3";

  src = fetchurl {
    url = "https://packages.microsoft.com/ubuntu/24.04/prod/pool/main/m/microsoft-identity-broker/microsoft-identity-broker_${version}_amd64.deb";
    hash = "sha256-vorPf5pvNLABwntiDdfDSiubg1jbHaKK/o0fFkbZ000=";
  };

  nativeBuildInputs = [ dpkg ];

  buildInputs = [
    dbus
    libuuid
    curlMinimal
    openssl_3
    xorg.libX11
    webkitgtk_4_1
    gtk3
    zlib
    pango
    harfbuzz
    atk
    cairo
    gdk-pixbuf
    libsoup_3
    libsecret
    glib
    p11-kit
    stdenv.cc.cc
  ];

  buildPhase = let
    libPath = lib.makeLibraryPath [
      stdenv.cc.cc
      dbus
      libuuid
      (curlMinimal.override { openssl = openssl_3; })
      openssl_3
      xorg.libX11
      webkitgtk_4_1
      gtk3
      zlib
      pango
      harfbuzz
      atk
      cairo
      gdk-pixbuf
      libsoup_3
      libsecret
      glib
      p11-kit
    ];
  in ''
    runHook preBuild

    patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) --set-rpath ${libPath} usr/bin/microsoft-identity-broker
    patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) --set-rpath ${libPath} usr/bin/microsoft-identity-device-broker

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -a usr/bin/* $out/bin/
    cp -a usr/share $out/
    cp -a usr/lib $out/

    substituteInPlace $out/share/dbus-1/services/com.microsoft.identity.broker1.service \
      --replace /usr/bin/microsoft-identity-broker $out/bin/microsoft-identity-broker

    substituteInPlace $out/share/dbus-1/system-services/com.microsoft.identity.devicebroker1.service \
      --replace /bin/false $out/bin/microsoft-identity-device-broker

    substituteInPlace $out/lib/systemd/system/microsoft-identity-device-broker.service \
      --replace /usr/bin/microsoft-identity-device-broker $out/bin/microsoft-identity-device-broker

    substituteInPlace $out/share/applications/microsoft-identity-broker.desktop \
      --replace /usr/bin/microsoft-identity-broker $out/bin/microsoft-identity-broker

    runHook postInstall
  '';

  dontPatchELF = true;

  meta = with lib; {
    description = "Microsoft Authentication Broker for Linux";
    homepage = "https://www.microsoft.com/";
    license = licenses.unfree;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ rhysmdnz ];
  };
}

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
  libglvnd,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  xorg,
  vips,
}:

stdenv.mkDerivation rec {
  pname = "pencil";
  version = "1.1.0";

  src = fetchurl {
    url = "https://5ykymftd1soethh5.public.blob.vercel-storage.com/Pencil-linux-x64.tar.gz";
    sha256 = "1g69x82d70cryclhvnj4dsvg1rm9n3qp9215ksccxr2wydn0sj4f";
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
    libglvnd
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemd
    vips
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
  ];

  unpackPhase = ''
    tar --no-same-permissions -xzf $src
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -r Pencil-${version}-linux-x64 $out/lib/pencil

    # Remove the suid chrome-sandbox (not needed with user namespaces)
    rm -f $out/lib/pencil/chrome-sandbox

    mkdir -p $out/bin
    makeWrapper $out/lib/pencil/pencil $out/bin/pencil \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --add-flags "--no-sandbox"

    # Create desktop entry
    mkdir -p $out/share/applications
    cat > $out/share/applications/pencil.desktop <<EOF
    [Desktop Entry]
    Name=Pencil
    Comment=Professional diagramming and design tool
    Exec=$out/bin/pencil %U
    Terminal=false
    Type=Application
    Categories=Graphics;Development;
    EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "Professional diagramming and design tool";
    homepage = "https://www.pencil.dev/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pencil";
  };
}

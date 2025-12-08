{
  buildFHSEnv,
  mise,
  pkg-config,
  # Build tools
  gcc,
  gnumake,
  autoconf,
  automake,
  libtool,
  bison,
  # Libraries (with dev headers)
  zlib,
  openssl,
  readline,
  libyaml,
  libffi,
  gmp,
  ncurses,
  # ImageMagick (for rmagick gem)
  imagemagick,
  # Additional utilities
  curl,
  git,
  rustc,
  cargo,
}:

buildFHSEnv {
  name = "mise";
  targetPkgs = pkgs: [
    mise
    pkg-config
    # Build tools
    gcc
    gnumake
    autoconf
    automake
    libtool
    bison
    # Libraries
    zlib
    zlib.dev
    openssl
    openssl.dev
    readline
    readline.dev
    libyaml
    libyaml.dev
    libffi
    libffi.dev
    gmp
    gmp.dev
    ncurses
    ncurses.dev
    # ImageMagick
    imagemagick
    imagemagick.dev
    # Utilities
    curl
    git
    rustc
    cargo
  ];
  runScript = "mise";
}

{
  lib,
  gcc15Stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  pandoc,
  util-linux,
  acl,
}:

gcc15Stdenv.mkDerivation {
  pname = "jai";
  version = "0.2-unstable-2026-03-27";

  src = fetchFromGitHub {
    owner = "stanford-scs";
    repo = "jai";
    rev = "46f507a4e0b4eb87950a095d19bbf837d79ecf57";
    hash = "sha256-OZrsNJrKe3gH3sGefrKgnFmDiMMP+xr4eM90hdGEDdg=";
  };

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
    pandoc
  ];

  buildInputs = [
    util-linux # libmount
    acl # libacl
  ];

  configureFlags = [
    "--with-untrusted-user=nobody"
  ];

  # Skip setuid install hooks (nix store is read-only)
  postInstall = ''
    chmod 0555 $out/bin/jai
  '';

  meta = {
    description = "Jail for AI - sandboxing tool for running untrusted code";
    homepage = "https://jai.scs.stanford.edu/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "jai";
  };
}

{ lib, gcc15Stdenv, fetchFromGitHub, autoreconfHook, pkg-config, pandoc
, util-linux, acl, }:

gcc15Stdenv.mkDerivation {
  pname = "jai";
  version = "0.3";

  src = fetchFromGitHub {
    owner = "stanford-scs";
    repo = "jai";
    rev = "7552ddea1633710538317a995d98421276fb0eca";
    hash = "sha256-AByC7Xh1FYbQ/4Au396m2zYUxsLqcF1PEbpdz7x6LaQ=";
  };

  nativeBuildInputs = [ autoreconfHook pkg-config pandoc ];

  buildInputs = [
    util-linux # libmount
    acl # libacl
  ];

  configureFlags = [ "--with-untrusted-user=nobody" ];

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

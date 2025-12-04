# Wrapped intune-portal with bwrap for Ubuntu os-release/lsb-release
{
  stdenv,
  lib,
  intune-portal,
  bubblewrap,
  writeShellScript,
  writeTextDir,
  symlinkJoin,
}:

let
  intuneWrapper = import ./intune-wrapper.nix { inherit writeShellScript bubblewrap writeTextDir symlinkJoin; };
  unwrapped = intune-portal;
in
stdenv.mkDerivation {
  pname = "intune-portal";
  inherit (unwrapped) version meta;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Symlink share and lib from unwrapped (no modifications needed)
    ln -s ${unwrapped}/share $out/share
    ln -s ${unwrapped}/lib $out/lib

    # Create bwrap wrapper for intune-portal only
    ln -s ${intuneWrapper.makeWrapper "${unwrapped}/bin/intune-portal"} $out/bin/intune-portal

    # Symlink other binaries without wrapper
    ln -s ${unwrapped}/bin/intune-agent $out/bin/intune-agent
    ln -s ${unwrapped}/bin/intune-daemon $out/bin/intune-daemon

    runHook postInstall
  '';
}

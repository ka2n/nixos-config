final: prev:
{
  # Wrapped intune-portal with bwrap for Ubuntu os-release/lsb-release
  intune-portal = final.callPackage ./pkgs/intune-portal.nix {
    intune-portal = prev.intune-portal;
  };

  # Wrapped microsoft-identity-broker with bwrap for Ubuntu os-release/lsb-release
  microsoft-identity-broker = final.callPackage ./pkgs/microsoft-identity-broker.nix { };
}

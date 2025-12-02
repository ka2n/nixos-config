final: prev:
let
  # Use nixpkgs version of intune-portal
  intunePortalUpdated = prev.intune-portal;

  # Use custom microsoft-identity-broker package
  identityBrokerUpdated = final.callPackage ./pkgs/microsoft-identity-broker.nix { };
in
{
  # No wrappers needed - system /etc/os-release is patched via activation script
  intune-portal = intunePortalUpdated;
  microsoft-identity-broker = identityBrokerUpdated;
}

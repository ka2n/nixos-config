# Microsoft Intune + Defender ATP module
# Includes all related packages, overlays, and GNOME dependencies
{ config, pkgs, lib, inputs, ... }:

{
  # Patch /etc/os-release with fake Ubuntu for Intune compatibility
  system.activationScripts.osRelease = lib.stringAfter [ "etc" ] ''
    rm -f /etc/os-release
    cat > /etc/os-release << 'EOF'
PRETTY_NAME="Ubuntu 24.04.1 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.1 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
EOF
  '';

  imports = [
    inputs.mdatp.nixosModules.mdatp
  ];

  # No overlays needed - system /etc/os-release is patched via activation script
  # nixpkgs.overlays = [
  #   (import ./overlays.nix)
  # ];

  # Microsoft Intune
  services.intune.enable = true;

  # Microsoft Defender ATP
  services.mdatp.enable = true;

  # GNOME Desktop (required for Intune authentication)
  services.desktopManager.gnome.enable = true;
  services.gnome.core-apps.enable = false;
  services.gnome.games.enable = false;
  services.gnome.gnome-keyring.enable = true;
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
  ];

  # libsecret for credential storage
  environment.systemPackages = [ pkgs.libsecret ];
}

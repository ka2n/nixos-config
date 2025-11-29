# Common configuration shared across all hosts
{ config, pkgs, ... }:

{
  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking
  networking.networkmanager.enable = true;

  # Timezone and locale
  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_CTYPE = "ja_JP.UTF-8";
  };

  # Keyboard
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # User
  users.users.k2 = {
    isNormalUser = true;
    description = "k2";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Common packages
  environment.systemPackages = with pkgs; [
    # Editors
    vim
    neovim

    # CLI tools
    git
    gh
    wget
    curl
    chezmoi

    # Wayland / Hyprland
    wl-clipboard
    wlogout
    waybar
    rofi
    hyprlock
    hypridle
    hyprpaper
    swaybg
    grim
    slurp
    dunst
  ];

  programs.fish.enable = true;

  # Hyprland
  programs.hyprland.enable = true;

  # Display manager
  services.displayManager.ly.enable = true;

  # Services
  services.openssh.enable = true;
  services.tailscale.enable = true;
}

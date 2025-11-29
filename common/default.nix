# Common configuration shared across all hosts
{ config, pkgs, ... }:

{
  # Nix settings
  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 7d";
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = ["root" "@wheel"];
  nix.settings.accept-flake-config = true;
  nixpkgs.config.allowUnfree = true;

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
  i18n.inputMethod.enable = true;
  i18n.inputMethod.type = "fcitx5";
  i18n.inputMethod.fcitx5.addons = with pkgs; [
    fcitx5-gtk
  ];

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

  # Common packages
  environment.systemPackages = with pkgs; [
    # Editors
    neovim

    # CLI tools
    git
    gh
    wget
    curl
    chezmoi
    mise
    tree
    tig

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
  programs.neovim.enable = true;
  programs.neovim.defaultEditor = true;
  programs.neovim.viAlias = true;
  programs.neovim.vimAlias = true;

  # Hyprland
  programs.hyprland.enable = true;

  # Display manager
  services.displayManager.ly.enable = true;

  # Services
  services.openssh.enable = true;
  services.tailscale.enable = true;

  fonts.fonts = with pkgs; [
    noto-fonts
  ];
}

# Common configuration shared across all hosts
{ config, pkgs, inputs, ... }:

let
  cica = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "cica";
    version = "5.0.3";
    src = pkgs.fetchzip {
      url = "https://github.com/miiton/Cica/releases/download/v${version}/Cica_v${version}.zip";
      hash = "sha256-XAi1XMTW3lKgz8MLcxT4VKfBvhkljUXPYAzrA3mqPLY=";
      stripRoot = false;
    };
    installPhase = ''
      runHook preInstall
      install -Dm644 *.ttf -t $out/share/fonts/truetype
      runHook postInstall
    '';
  };
in
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
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };

  # Common packages
  environment.systemPackages = (with pkgs; [
    # Editors
    neovim

    # CLI tools
    gh
    wget
    curl
    chezmoi
    mise
    tree
    tig

    # Browsers
    google-chrome
    firefox

    # Communication
    slack

    # Note-taking
    obsidian

    # Office
    libreoffice

    # File manager
    xfce.thunar

    # Media
    vlc
    feh

    # System utilities
    blueman
    pavucontrol

    # Music
    spotify

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
  ]) ++ [
    # External flake packages
    inputs.zen-browser.packages.${pkgs.system}.default
  ];

  programs.fish.enable = true;
  programs.git.enable = true;
  programs.neovim.enable = true;
  programs.neovim.defaultEditor = true;
  programs.neovim.viAlias = true;
  programs.neovim.vimAlias = true;

  # Hyprland
  programs.hyprland.enable = true;

  # 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "k2" ];
  };

  # Allow Zen Browser to connect to 1Password
  environment.etc."1password/custom_allowed_browsers" = {
    text = ''
      zen
    '';
    mode = "0755";
  };

  # Display manager
  services.displayManager.ly.enable = true;

  # Services
  services.openssh.enable = true;
  services.tailscale.enable = true;

  # Docker
  virtualisation.docker.enable = true;

  fonts.fonts = (with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
  ]) ++ [
    cica
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "Noto Serif" "Noto Serif CJK JP" ];
      sansSerif = [ "Noto Sans" "Noto Sans CJK JP" ];
      monospace = [ "Cica" "Noto Sans Mono CJK JP" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}

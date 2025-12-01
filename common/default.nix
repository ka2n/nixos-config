# Common configuration shared across all hosts
{ config, pkgs, inputs, ... }:

let
  cica = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "cica";
    version = "5.0.3";
    src = pkgs.fetchzip {
      url = "https://github.com/miiton/Cica/releases/download/v${version}/Cica_v${version}.zip";
      hash = "sha256-BtDnfWCfD9NE8tcWSmk8ciiInsspNPTPmAdGzpg62SM=";
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
  i18n.inputMethod.fcitx5.waylandFrontend = true;
  i18n.inputMethod.fcitx5.addons = with pkgs; [
    fcitx5-gtk
    fcitx5-cskk
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
    ldns          # drill
    dig
    ripgrep
    jq
    fzf
    fd
    bat
    lsd
    colordiff
    peco
    ghq
    just
    yazi
    pulsemixer
    libsecret

    # Terminal
    kitty
    alacritty
    tmux

    # Shell enhancements
    starship
    atuin

    # Keyboard/Input
    xremap
    warpd
    inputactions-hyprland       # Mouse/touchpad gestures (easystroke alternative)

    # Development
    go
    python3
    nodejs
    claude-code
    codex
    gemini-cli-bin

    # Build tools
    gcc
    gnumake
    cmake
    pkg-config
    binutils
    zlib
    readline
    libyaml
    libffi
    ncurses
    gdbm
    openssl
    rustc
    cargo
    groff
    autoconf
    automake
    bison
    libtool
    jemalloc
    unzip
    p7zip

    # Browsers
    google-chrome
    firefox
    microsoft-edge

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
    dex                         # XDG autostart runner
    tailscale-systray           # Tailscale system tray icon
    darkman                     # Dark/light mode daemon

    # GUI Settings tools
    networkmanagerapplet        # nm-applet + nm-connection-editor
    nwg-displays                # Display/monitor configuration
    nwg-look                    # GTK theme settings (lxappearance alternative)
    cameractrls                 # Webcam settings (Camset)
    cameractrls-gtk3

    # Music
    spotify

    # Wayland / Hyprland
    wl-clipboard
    cliphist                    # Clipboard history (use with rofi)
    wlogout
    waybar
    rofi
    hyprpaper
    swaybg
    grim
    slurp
    swappy                      # Screenshot annotation tool
    mako                        # notification daemon (omarchy style)
    libnotify

    # Theming (omarchy style)
    gnome-themes-extra          # Adwaita GTK theme
    yaru-theme                  # Yaru icon theme

    # SKK
    skkDictionaries.l
  ]) ++ [
    # External flake packages
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  documentation.man.generateCaches = false;

  programs.nix-ld.enable = true;
  programs.fish.enable = true;
  programs.git.enable = true;
  programs.neovim.enable = true;
  programs.neovim.defaultEditor = true;
  programs.neovim.viAlias = true;
  programs.neovim.vimAlias = true;

  # Hyprland
  programs.hyprland.enable = true;
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;

  programs.seahorse.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.ly.enableGnomeKeyring = true;

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

  # NoiseTorch - microphone noise suppression
  programs.noisetorch.enable = true;

  # Display manager
  services.displayManager.ly.enable = true;
  services.xserver.desktopManager.runXdgAutostartIfNone = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-hyprland
    pkgs.xdg-desktop-portal-gtk
  ];

  # Services
  services.openssh.enable = true;
  services.tailscale.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Audio (PipeWire)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Docker
  virtualisation.docker.enable = true;

  fonts.packages = (with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono   # omarchy waybar font
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

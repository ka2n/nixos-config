# Common configuration shared across all hosts
{ config, pkgs, lib, inputs, pkgs-unstable, ... }:

let
  cica = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "cica";
    version = "5.0.3";
    src = pkgs.fetchzip {
      url =
        "https://github.com/miiton/Cica/releases/download/v${version}/Cica_v${version}.zip";
      hash = "sha256-BtDnfWCfD9NE8tcWSmk8ciiInsspNPTPmAdGzpg62SM=";
      stripRoot = false;
    };
    installPhase = ''
      runHook preInstall
      install -Dm644 *.ttf -t $out/share/fonts/truetype
      runHook postInstall
    '';
  };

  # Hyprland plugins directory
  hypr-plugin-dir = pkgs.symlinkJoin {
    name = "hyprland-plugins";
    paths = [ inputs.inputactions.packages.x86_64-linux.inputactions-hyprland ];
  };
in {
  imports = [
    ../modules/zen-browser
    ../modules/mise
    ../modules/hypr-scripts
    ../modules/xremap.nix
    ../modules/webcam-flicker.nix
    ../modules/local-ca
    ../modules/display/dell-s2722qc-edid.nix
    ../modules/display/aquamarine-broadcast-rgb.nix
  ];
  # Nix settings
  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 7d";
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.settings.accept-flake-config = true;
  nixpkgs.config.allowUnfree = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel (can be overridden by host-specific config)
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # Networking
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  # Workaround for iptables 1.8.11 bug breaking Docker bridge networks
  # https://github.com/NixOS/nixpkgs/issues/417641
  networking.firewall.trustedInterfaces = [ "br+" ];
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;
  services.avahi.ipv6 = false;

  # Timezone and locale
  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = { LC_CTYPE = "ja_JP.UTF-8"; };
  i18n.inputMethod.enable = true;
  i18n.inputMethod.type = "fcitx5";
  i18n.inputMethod.fcitx5.waylandFrontend = true;
  i18n.inputMethod.fcitx5.addons = with pkgs; [ fcitx5-gtk fcitx5-cskk ];

  # fcitx5入力メソッド設定
  i18n.inputMethod.fcitx5.settings = {
    inputMethod = {
      "Groups/0" = {
        Name = "Default";
        "Default Layout" = "us";
        DefaultIM = "cskk";
      };
      "Groups/0/Items/0".Name = "cskk";
      "Groups/0/Items/1".Name = "keyboard-us";
      GroupOrder."0" = "Default";
    };
  };

  systemd.user.targets.hyprland-session = {
    unitConfig = {
      Description = "Hyprland compositor session";
      Documentation = [ "man:systemd.special(7)" ];
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };

  # Keyboard
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # xremap
  programs.xremap.enable = true;

  # User
  users.users.k2 = {
    isNormalUser = true;
    description = "k2";
    extraGroups = [ "networkmanager" "wheel" "docker" "uinput" ];
  };

  # Common packages
  environment.systemPackages = (with pkgs; [
    # Editors
    neovim
    code-cursor-fhs

    # CLI tools
    coreutils
    gawk
    file
    bubblewrap # Sandboxing tool
    gh
    wget
    curl
    chezmoi
    tree
    tig
    ldns # drill
    dig
    ripgrep
    jq
    fzf
    fd
    bat
    colordiff
    peco
    yazi
    pulsemixer
    wiremix # PipeWire TUI mixer
    swaylock # Fallback screen locker
    libsecret
    gcr
    playerctl
    bluetui

    # From aqua migration (system-level tools)
    yq-go
    cloudflared

    # Terminal
    kitty
    alacritty-graphics
    (tmux.override { withSixel = true; })

    # Shell enhancements
    starship
    atuin

    # Keyboard/Input
    warpd
    inputs.inputactions.packages.x86_64-linux.inputactions-hyprland # Mouse/touchpad gestures (easystroke alternative)
    inputs.inputactions.packages.x86_64-linux.inputactions-ctl

    # Development
    go
    python3
    nodejs
    pkgs.claude-code-wrapped
    alma
    codex
    gemini-cli-bin
    delta

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
    rustup
    groff
    autoconf
    automake
    bison
    libtool
    jemalloc
    patchelf
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

    # Design
    figma-linux

    # File manager
    xfce.thunar

    # Media
    vlc
    feh
    kooha

    # System utilities
    blueman
    pavucontrol
    dex # XDG autostart runner
    tailscale-systray # Tailscale system tray icon
    darkman # Dark/light mode daemon
    sound-theme-freedesktop
    pulseaudio

    # GUI Settings tools
    networkmanagerapplet # nm-applet + nm-connection-editor
    nwg-look # GTK theme settings (lxappearance alternative)
    cameractrls # Webcam settings (Camset)
    cameractrls-gtk3

    # Music
    spotify

    # Password Manager
    keeper-desktop

    # Wayland / Hyprland
    wl-clipboard
    clipse # Clipboard manager TUI
    waybar
    rofi
    hyprpaper
    rose-pine-hyprcursor
    grim
    slurp
    swappy # Screenshot annotation tool
    mako # notification daemon (omarchy style)
    libnotify
    darkman
    wlsunset
    glib
    gtk3 # gtk-launch

    # Theming (omarchy style)
    gnome-themes-extra # Adwaita GTK theme
    yaru-theme # Yaru icon theme
    nordic

    # SKK
    skkDictionaries.l
  ]);

  # Link SKK dictionaries to /run/current-system/sw/share/skk/
  environment.pathsToLink = [ "/share/skk" ];

  # Provide /bin/bash, /usr/bin/env, etc. for compatibility with FHS scripts
  services.envfs.enable = true;

  # Add $HOME/.local/bin to PATH
  environment.sessionVariables.PATH = [ "$HOME/.local/bin" ];

  # Hyprland plugins directory
  environment.sessionVariables.HYPR_PLUGIN_DIR = "${hypr-plugin-dir}/lib";

  # GTK Emacs keybindings (Ctrl-W for word delete, etc.)
  environment.sessionVariables.GTK_KEY_THEME = "Emacs";

  documentation.man.generateCaches = false;

  # nix-ld is configured by programs.mise module
  # Fish is configured in home-manager (for plugin support)
  programs.git.enable = true;
  programs.neovim.enable = true;
  programs.neovim.defaultEditor = true;
  programs.neovim.viAlias = true;
  programs.neovim.vimAlias = true;

  # Zen Browser
  programs.zen-browser.enable = true;

  # Hyprland
  programs.hyprland.enable = true;
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;

  # Override hypridle to only start under hyprland-session.target (not gdm-greeter)
  systemd.user.services.hypridle = {
    wantedBy = lib.mkForce [ "hyprland-session.target" ];
    after = lib.mkForce [ "hyprland-session.target" ];
  };

  # Swaylock (fallback screen locker)
  security.pam.services.swaylock = { };

  # Polkit
  security.polkit.enable = true;

  programs.seahorse.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.gdm.enableGnomeKeyring = true;

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

  # mise - polyglot runtime manager
  programs.mise.enable = true;

  # Hyprland utility scripts (terminal wrappers, rofi scripts)
  programs.hypr-scripts.enable = true;

  # NoiseTorch - microphone noise suppression
  programs.noisetorch.enable = true;

  # Display manager (GDM)
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.runXdgAutostartIfNone = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals =
    [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.config = {
    common = { default = [ "hyprland" "gtk" ]; };
    hyprland = {
      default = [ "hyprland" "gtk" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    };
  };

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
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      registry-mirrors = [ "https://mirror.gcr.io" ];
    };
  };

  fonts.packages = (with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono # omarchy waybar font
  ]) ++ [ cica ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "Noto Serif" "Noto Serif CJK JP" ];
      sansSerif = [ "Noto Sans" "Noto Sans CJK JP" ];
      monospace = [ "Cica" "Noto Sans Mono CJK JP" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # Local CA for HTTPS development (Caddy)
  security.localCA = {
    enable = true;
    certificateFile = ../certs/local-ca.crt;
    sopsSecretFile = ../secrets/local-ca.yaml;
    extraDomainsSecretFile = ../secrets/local-ca-extra-domains.enc;
  };
}

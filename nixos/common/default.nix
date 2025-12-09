# Common configuration shared across all hosts
{ config, pkgs, lib, inputs, ... }:

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
  imports = [
    ../modules/zen-browser
    ../modules/mise
    ../modules/hypr-terminal-apps
  ];
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

  # Use latest kernel (can be overridden by host-specific config)
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

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

  systemd.user.targets.hyprland-session = {
      unitConfig = {
          Description = "Hyprland compositor session";
          Documentation = ["man:systemd.special(7)"];
          BindsTo = ["graphical-session.target"];
          Wants = ["graphical-session-pre.target"];
          After = ["graphical-session-pre.target"];
      };
  };


  # Keyboard
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # xremap - udev rules for /dev/uinput access
  hardware.uinput.enable = true;
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="users", MODE="0660"
  '';

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
    wiremix             # PipeWire TUI mixer
    swaylock            # Fallback screen locker
    libsecret
    gcr
    playerctl
    bluetui

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
    inputs.inputactions.packages.x86_64-linux.inputactions-hyprland  # Mouse/touchpad gestures (easystroke alternative)
    inputs.inputactions.packages.x86_64-linux.inputactions-ctl

    # Development
    go
    python3
    nodejs
    claude-code
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
    rustc
    cargo
    groff
    autoconf
    automake
    bison
    libtool
    jemalloc
    patchelf
    file
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

    # System utilities
    blueman
    pavucontrol
    dex                         # XDG autostart runner
    tailscale-systray           # Tailscale system tray icon
    darkman                     # Dark/light mode daemon
    sound-theme-freedesktop
    pulseaudio

    # GUI Settings tools
    networkmanagerapplet        # nm-applet + nm-connection-editor
    nwg-look                    # GTK theme settings (lxappearance alternative)
    cameractrls                 # Webcam settings (Camset)
    cameractrls-gtk3

    # Music
    spotify

    # Password Manager
    keeper-desktop

    # Wayland / Hyprland
    wl-clipboard
    clipse                      # Clipboard manager TUI
    wlogout
    waybar
    rofi
    hyprpaper
    rose-pine-hyprcursor
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
  ]);

  # Link SKK dictionaries to /run/current-system/sw/share/skk/
  environment.pathsToLink = [ "/share/skk" ];

  # Add $HOME/.local/bin to PATH
  environment.sessionVariables.PATH = [ "$HOME/.local/bin" ];

  documentation.man.generateCaches = false;

  # nix-ld is configured by programs.mise module
  programs.fish.enable = true;
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
  security.pam.services.swaylock = {};

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

  # InputActions Hyprland plugin symlink
  environment.etc."hyprland/plugins/libinputactions_hyprland.so".source =
    "${inputs.inputactions.packages.x86_64-linux.inputactions-hyprland}/lib/libinputactions_hyprland.so";

  # mise - polyglot runtime manager
  programs.mise.enable = true;

  # Terminal apps with alacritty wrapper (for Hyprland)
  programs.hypr-terminal-apps.enable = true;

  # NoiseTorch - microphone noise suppression
  programs.noisetorch.enable = true;

  # Display manager (GDM)
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.runXdgAutostartIfNone = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-hyprland
    pkgs.xdg-desktop-portal-gtk
  ];
  xdg.portal.config = {
    common = {
      default = ["hyprland" "gtk"];
    };
    hyprland = {
      default = ["hyprland" "gtk"];
      "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
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

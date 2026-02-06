{ config, pkgs, inputs, lib, osConfig ? null, variant ? "desktop", ... }:
let
  # Check if himmelblau is enabled via NixOS module and get package from there
  hasHimmelblau = osConfig.services.azure-entra.enable or false;
  himmelblauPkg = if hasHimmelblau then osConfig.services.azure-entra.package else null;
  zenBrowser = pkgs.wrapFirefox
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.zen-browser-unwrapped {
      pname = "zen-browser";
      extraPolicies = lib.optionalAttrs hasHimmelblau {
        ExtensionSettings = {
          "linux-entra-sso@example.com" = {
            install_url =
              "https://github.com/siemens/linux-entra-sso/releases/download/v1.7.1/linux_entra_sso-1.7.1.xpi";
            installation_mode = "normal_installed";
          };
        };
      };
    };
in {
  home.stateVersion = "25.11";

  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  home.packages = [
    pkgs.delta
    pkgs.lf
    pkgs.ffmpegthumbnailer
    pkgs.chafa
    pkgs.imagemagick # for convert and identify

    # Phase 3: Additional packages
    # tailscale-systray removed - using official `tailscale systray` command

    # From aqua migration (user-level tools)
    pkgs.ghq
    pkgs.git-who
    pkgs.kubectx
    pkgs.stern
    pkgs.snyk
    pkgs.just
    pkgs.jnv
    pkgs.lsd
    pkgs.curlie
    pkgs.vhs
    pkgs.git-wt
    pkgs.go-readability

    # Docker
    pkgs.docker-credential-helpers

    # Local bin scripts
    (pkgs.writeShellScriptBin "find-parent-package-dir"
      (builtins.replaceStrings [ "@git@" ] [ "${lib.getExe pkgs.git}" ]
        (builtins.readFile ./dotfiles/local/bin/find-parent-package-dir.sh)))

    (pkgs.writeScriptBin "x-open-url" ''
      #!${lib.getExe' pkgs.nodejs "node"}
      ${builtins.readFile ./dotfiles/local/bin/x-open-url.js}
    '')

    (pkgs.writeShellScriptBin "claude-notify-waiting"
      (builtins.readFile ./dotfiles/local/bin/claude-notify-waiting.sh))

    (pkgs.writeShellScriptBin "claude-notify-complete"
      (builtins.readFile ./dotfiles/local/bin/claude-notify-complete.sh))

    (pkgs.writeShellScriptBin "ndev" ''
      exec nix develop "$HOME/nixos-config" --command "$SHELL"
    '')

    (pkgs.writeShellScriptBin "save-url-to-doc"
      (builtins.replaceStrings
        [ "@readability@" "@git@" "@wl_paste@" "@sed@" "@mkdir@" "@mv@" ]
        [
          (lib.getExe pkgs.go-readability)
          (lib.getExe pkgs.git)
          (lib.getExe' pkgs.wl-clipboard "wl-paste")
          (lib.getExe' pkgs.gnused "sed")
          (lib.getExe' pkgs.coreutils "mkdir")
          (lib.getExe' pkgs.coreutils "mv")
        ]
        (builtins.readFile ./dotfiles/local/bin/save-url-to-doc.sh)))

    (pkgs.writeShellScriptBin "git-delete-merged"
      (builtins.replaceStrings [ "@git@" "@git_wt@" ]
        [ (lib.getExe pkgs.git) (lib.getExe pkgs.git-wt) ]
        (builtins.readFile ./dotfiles/local/bin/git-delete-merged.sh)))

    (pkgs.writeShellScriptBin "tf-pr" ''
      set -euo pipefail

      if [ $# -lt 1 ]; then
        echo "Usage: tf-pr <PR_NUM> [plan|apply]" >&2
        exit 1
      fi

      PR_NUM="$1"
      ACTION="''${2:-plan}"

      if [ "$ACTION" != "plan" ] && [ "$ACTION" != "apply" ]; then
        echo "Error: action must be 'plan' or 'apply'" >&2
        exit 1
      fi

      OWNER=$(${lib.getExe pkgs.gh} repo view --json owner -q '.owner.login')
      REPO=$(${lib.getExe pkgs.gh} repo view --json name -q '.name')

      exec tfcmt -owner "$OWNER" -repo "$REPO" -pr "$PR_NUM" "$ACTION" -- terraform "$ACTION"
    '')
  ];

  home.sessionPath = [
    "$HOME/go/bin"
    "$HOME/.local/bin"
    "$HOME/.local/share/aquaproj-aqua/bin"
  ];

  home.sessionVariables = {
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent.socket";
    GITHUB_USER = "ka2n";
    EDITOR = "nvim";
    AQUA_GLOBAL_CONFIG = "$HOME/.config/aquaproj-aqua/aqua.yaml";
    AQUA_POLICY_CONFIG = "$HOME/.config/aquaproj-aqua/aqua-policy.yaml";

    # GTK IM module (for all GTK versions)
    GTK_IM_MODULE = "fcitx";
  };

  xdg.configFile."git/config".source = pkgs.replaceVars ./dotfiles/git/config {
    op_ssh_sign = lib.getExe' pkgs._1password-gui "op-ssh-sign";
  };
  xdg.configFile."git/ignore".source = ./dotfiles/git/ignore;

  xdg.configFile."tmux/tmux.conf".source =
    pkgs.replaceVars ./dotfiles/tmux/tmux.conf {
      fish_path = lib.getExe pkgs.fish;
    };

  # Config files
  xdg.configFile."inputactions/config.yaml".source =
    ./dotfiles/inputactions/config.yaml;
  xdg.configFile."clipse/config.json".source = ./dotfiles/clipse/config.json;
  xdg.configFile."darkman/config.yaml".source = ./dotfiles/darkman/config.yaml;
  xdg.configFile."bluetui/config.toml".source = ./dotfiles/bluetui/config.toml;
  xdg.configFile."tig/config".source = ./dotfiles/tig/config;
  xdg.configFile."atuin/config.toml".source = ./dotfiles/atuin/config.toml;
  xdg.configFile."gh/config.yml".source = ./dotfiles/gh/config.yml;
  xdg.configFile."mako/config".source = ./dotfiles/mako/config;
  xdg.configFile."wlogout/layout".source = ./dotfiles/wlogout/layout;
  xdg.configFile."x-open-url/config.json".source =
    pkgs.replaceVars ./dotfiles/x-open-url/config.json {
      zen_browser = lib.getExe zenBrowser;
      google_chrome = lib.getExe pkgs.google-chrome;
    };

  # Docker credential helpers configuration
  xdg.configFile."docker/config.json".text = builtins.toJSON {
    credsStore = "secretservice";
    credHelpers = {
      "asia-northeast1-docker.pkg.dev" = "gcloud";
      "asia.gcr.io" = "gcloud";
      "eu.gcr.io" = "gcloud";
      "gcr.io" = "gcloud";
      "marketplace.gcr.io" = "gcloud";
      "staging-k8s.gcr.io" = "gcloud";
      "us-central1-docker.pkg.dev" = "gcloud";
      "us-east1-docker.pkg.dev" = "gcloud";
      "us.gcr.io" = "gcloud";
    };
  };

  # Fish shell configuration and plugins (migrated from fisher)
  # Let home-manager generate config.fish with plugin loaders,
  # and add our custom config via conf.d
  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "fish-bd";
        src = pkgs.fishPlugins.fish-bd.src;
      }
      {
        name = "bass";
        src = pkgs.fishPlugins.bass.src;
      }
      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }
      {
        name = "z";
        src = pkgs.fishPlugins.z.src;
      }
    ];
  };

  # Add custom config via conf.d (loaded after plugins)
  xdg.configFile."fish/conf.d/zzz-custom.fish".source =
    ./dotfiles/fish/conf.d-custom.fish;

  # GTK 2.0 - use .gtkrc-2.0.mine for customization (nwg-look compatible)
  home.file.".gtkrc-2.0.mine".source = ./dotfiles/gtkrc-2.0.mine;

  # Phase 1: Starship
  xdg.configFile."starship.toml".source = ./dotfiles/starship.toml;

  # Phase 2: Aqua package manager
  xdg.configFile."aquaproj-aqua/aqua.yaml".source =
    ./dotfiles/aquaproj-aqua/aqua.yaml;
  xdg.configFile."aquaproj-aqua/aqua-policy.yaml".source =
    ./dotfiles/aquaproj-aqua/aqua-policy.yaml;

  # Phase 3: fcitx5-cskk辞書設定
  xdg.configFile."fcitx5/cskk/dictionary_list".text =
    let inherit (pkgs) skkDictionaries;
    in ''
      type,file,mode,encoding,complete
      file,$FCITX_CONFIG_DIR/cskk/user.dict,readwrite,utf-8,
      file,${skkDictionaries.l}/share/skk/SKK-JISYO.L,readonly,euc-jp,
      file,${skkDictionaries.emoji}/share/skk/SKK-JISYO.emoji,readonly,utf-8,
      file,${skkDictionaries.zipcode}/share/skk/SKK-JISYO.zipcode,readonly,euc-jp,
    '';

  # Multi-file configs
  xdg.configFile."rofi" = {
    source = ./dotfiles/rofi;
    recursive = true;
  };
  xdg.configFile."lf/lfrc".source = let
    lf-previewer = pkgs.replaceVarsWith {
      src = ./dotfiles/lf/previewer.sh;
      isExecutable = true;
      replacements = {
        stat = lib.getExe' pkgs.coreutils "stat";
        readlink = lib.getExe' pkgs.coreutils "readlink";
        sha256sum = lib.getExe' pkgs.coreutils "sha256sum";
        awk = lib.getExe' pkgs.gawk "awk";
        chafa = lib.getExe pkgs.chafa;
        file = lib.getExe pkgs.file;
        identify = lib.getExe' pkgs.imagemagick "identify";
        convert = lib.getExe' pkgs.imagemagick "convert";
        ffmpegthumbnailer = lib.getExe pkgs.ffmpegthumbnailer;
        fold = lib.getExe' pkgs.coreutils "fold";
      };
    };
    lf-previewer-sandboxed = pkgs.replaceVarsWith {
      src = ./dotfiles/lf/previewer-wrapper.sh;
      isExecutable = true;
      replacements = {
        bwrap = lib.getExe pkgs.bubblewrap;
        previewer_script = "${lf-previewer}";
      };
    };
  in pkgs.replaceVars ./dotfiles/lf/lfrc {
    previewer = "${lf-previewer-sandboxed}";
  };
  xdg.configFile."waybar/config.jsonc".source = ./dotfiles/waybar/config.jsonc;
  xdg.configFile."waybar/config-river.jsonc".source =
    ./dotfiles/waybar/config-river.jsonc;
  xdg.configFile."waybar/style.css".source = ./dotfiles/waybar/style.css;
  xdg.configFile."hypr" = {
    source = ./dotfiles/hypr;
    recursive = true;
  };
  # hypridle - idle management (works with both Hyprland and River)
  services.hypridle = {
    enable = true;
    systemdTarget = "river-session.target";
    settings = let
      lockTimeout = if variant == "laptop" then 300 else 900;
      screenOffTimeout = if variant == "laptop" then 420 else 1800;
      suspendTimeout = if variant == "laptop" then 1800 else 28800;
    in {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock --grace 10";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "wlopm --on '*'";
      };
      listener = [
        {
          timeout = lockTimeout;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = screenOffTimeout;
          on-timeout = "wlopm --off '*'";
          on-resume = "wlopm --on '*'";
        }
        {
          timeout = suspendTimeout;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
  xdg.configFile."alacritty" = {
    source = ./dotfiles/alacritty;
    recursive = true;
  };
  xdg.configFile."nvim" = {
    source = ./dotfiles/nvim;
    recursive = true;
  };

  # xdg-desktop-portal configuration
  # Note: User-level config completely overrides system-level (NixOS) config
  # So we must include all settings here, not just darkman
  # extraPortals also required - sets NIX_XDG_DESKTOP_PORTAL_DIR to user profile
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-wlr
      pkgs.darkman
      pkgs.gnome-keyring
    ];
    config = {
      common = {
        default = [ "wlr" "gtk" ];
        "org.freedesktop.impl.portal.Settings" = [ "darkman" ];
      };
      river = {
        default = [ "wlr" "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        "org.freedesktop.impl.portal.Settings" = [ "darkman" ];
      };
    };
  };

  # xdg-open URL handler
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # x-open-url for HTTP/HTTPS
      "x-scheme-handler/http" = "x-open-url.desktop";
      "x-scheme-handler/https" = "x-open-url.desktop";

      # Migrated from existing mimeapps.list (NixOS-managed only)
      "x-scheme-handler/figma" = "figma-linux.desktop";
      "inode/directory" = "thunar.desktop";
      "inode/mount-point" = "thunar.desktop";
      "image/png" = "feh.desktop";
      "text/html" = "zen.desktop";
      "x-scheme-handler/chrome" = "zen.desktop";
      "application/x-extension-htm" = "zen.desktop";
      "application/x-extension-html" = "zen.desktop";
      "application/x-extension-shtml" = "zen.desktop";
      "application/xhtml+xml" = "zen.desktop";
      "application/x-extension-xhtml" = "zen.desktop";
      "application/x-extension-xht" = "zen.desktop";
      "text/plain" = "nvim.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
      "x-scheme-handler/obsidian" = "obsidian.desktop";
    };
  };

  # Desktop files
  home.file.".local/share/applications/x-open-url.desktop".source =
    ./dotfiles/local/share/applications/x-open-url.desktop;

  # Darkman hooks
  home.file.".local/share/dark-mode.d/notify.sh" = {
    source = pkgs.replaceVars ./dotfiles/local/share/dark-mode.d/notify.sh {
      notify_send = lib.getExe pkgs.libnotify;
    };
    executable = true;
  };
  home.file.".local/share/dark-mode.d/theme.sh" = {
    source = pkgs.replaceVars ./dotfiles/local/share/dark-mode.d/theme.sh {
      dconf = lib.getExe' pkgs.dconf "dconf";
    };
    executable = true;
  };
  home.file.".local/share/light-mode.d/notify.sh" = {
    source = pkgs.replaceVars ./dotfiles/local/share/light-mode.d/notify.sh {
      notify_send = lib.getExe pkgs.libnotify;
    };
    executable = true;
  };
  home.file.".local/share/light-mode.d/theme.sh" = {
    source = pkgs.replaceVars ./dotfiles/local/share/light-mode.d/theme.sh {
      dconf = lib.getExe' pkgs.dconf "dconf";
    };
    executable = true;
  };

  home.file.".bashrc".source = ./dotfiles/bashrc;
  home.file.".env.1password".source = ./dotfiles/env.1password;
  home.file.".tridactylrc".source = ./dotfiles/tridactylrc;
  home.file.".terraformrc".source = ./dotfiles/terraformrc;
  home.file.".yarnrc".source = ./dotfiles/yarnrc;
  home.file.".claude" = {
    source = ./dotfiles/claude;
    recursive = true;
  };

  # Phase 0: Claude settings.local.json (inline management with stop hook)
  home.file.".claude/settings.local.json".text = builtins.toJSON {
    outputStyle = "default";
    hooks = {
      Stop = [{
        matcher = "";
        hooks = [{
          type = "command";
          command =
            "paplay /run/current-system/sw/share/sounds/freedesktop/stereo/bell.oga";
        }];
      }];
    };
  };

  # Phase 1: vim templates
  home.file.".templates" = {
    source = ./dotfiles/templates;
    recursive = true;
  };

  # GTK 3.0/4.0 - Ensure Emacs keybindings persist with nwg-look
  home.activation.gtkKeyTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # GTK 3.0
    mkdir -p ~/.config/gtk-3.0
    if [ -f ~/.config/gtk-3.0/settings.ini ]; then
      if ! grep -q "gtk-key-theme-name" ~/.config/gtk-3.0/settings.ini; then
        echo "gtk-key-theme-name=Emacs" >> ~/.config/gtk-3.0/settings.ini
      fi
    else
      echo "[Settings]" > ~/.config/gtk-3.0/settings.ini
      echo "gtk-key-theme-name=Emacs" >> ~/.config/gtk-3.0/settings.ini
    fi

    # GTK 4.0
    mkdir -p ~/.config/gtk-4.0
    if [ -f ~/.config/gtk-4.0/settings.ini ]; then
      if ! grep -q "gtk-key-theme-name" ~/.config/gtk-4.0/settings.ini; then
        echo "gtk-key-theme-name=Emacs" >> ~/.config/gtk-4.0/settings.ini
      fi
    else
      echo "[Settings]" > ~/.config/gtk-4.0/settings.ini
      echo "gtk-key-theme-name=Emacs" >> ~/.config/gtk-4.0/settings.ini
    fi
  '';

  programs.nix-index-database.comma.enable = true;

  # Systemd user services
  # Tailscale systray (official command, not third-party package)
  # https://tailscale.com/kb/1597/linux-systray
  systemd.user.services.tailscale-systray = {
    Unit = {
      Description = "Tailscale System Tray";
      Documentation = [ "https://tailscale.com/kb/1597/linux-systray" ];
      Requires = [ "dbus.service" ];
      After = [ "dbus.service" "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.tailscale}/bin/tailscale systray";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

  systemd.user.services.xremap = let
    devices = [
      "HHKB-Hybrid_1 Keyboard"
      "PFU Limited HHKB-Hybrid"
      "Logitech ERGO M575"
      "Keyboardio Atreus"
      "Kensington SlimBlade Pro(2.4GHz Receiver) Kensington SlimBlade Pro Trackball(2.4GHz Receiver)"
    ];
    deviceArgs = map (d: "--device '${d}'") devices;
  in {
    Unit = {
      Description = "xremap keyboard remapper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      KillMode = "process";
      ExecStart = lib.concatStringsSep " "
        ([ (lib.getExe pkgs.xremap) "--watch=config,device" ] ++ deviceArgs
          ++ [ (toString ./dotfiles/xremap/config.yml) ]);
      Restart = "on-failure";
      RestartSec = "5s";
      StandardOutput = "null";
      StandardError = "journal";
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

  # InputActions client (for River - window info provider)
  # Note: inputactionsd runs as system service (requires root)
  systemd.user.services.inputactions-client = {
    Unit = {
      Description = "InputActions Client (standalone)";
      PartOf = [ "river-session.target" ];
      After = [ "river-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.inputactions-standalone}/bin/inputactions-client";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = { WantedBy = [ "river-session.target" ]; };
  };

  # River window manager
  wayland.windowManager.river = {
    enable = true;
    package = null; # Use system package from programs.river.enable
    systemd.enable = true; # Auto-start river-session.target

    extraSessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      XCURSOR_THEME = "Adwaita";
      XCURSOR_SIZE = "24";
    };
  };

  # River init script (managed separately for flexibility)
  # Use mkForce to override home-manager's river module generated init
  xdg.configFile."river/init" = lib.mkForce {
    source = ./dotfiles/river/init;
    executable = true;
  };

  # Kanshi - auto display configuration for River
  xdg.configFile."kanshi/config".source = ./dotfiles/kanshi/config;

  programs.firefox = {
    enable = true;
    nativeMessagingHosts = [ pkgs.tridactyl-native ]
      ++ lib.optional hasHimmelblau himmelblauPkg.firefoxNativeMessagingHost;
    package = zenBrowser;
    configPath = ".zen";

    profiles.default = {
      isDefault = true;
      settings = {
        # Zen Browser specific
        "zen.welcome-screen.seen" = true;
        "zen.urlbar.replace-newtab" = false;
        "zen.view.compact.enable-at-startup" = false;

        # Browser behavior
        "browser.ctrlTab.sortByRecentlyUsed" = true;
        "browser.startup.homepage" = "chrome://browser/content/blanktab.html";
        "browser.startup.page" = 1;
        "browser.ml.enable" = true;

        # Privacy & Security
        "dom.security.https_only_mode_ever_enabled" = true;

        # Localization
        "browser.translations.neverTranslateLanguages" = "ja";
      };
    };
  };
}

{ config, pkgs, pkgs-unstable, inputs, lib, llm-agents, osConfig ? null
, variant ? "desktop", riverBackgroundColor ? null, ... }:
let
  # Check if himmelblau is enabled via NixOS module and get package from there
  hasHimmelblau = osConfig.services.himmelblau.enable or false;
  himmelblauPkg =
    if hasHimmelblau then osConfig.services.himmelblau.package else null;
  x-open-url = pkgs.writeScriptBin "x-open-url" ''
    #!${lib.getExe' pkgs.nodejs "node"}
    ${builtins.readFile ./dotfiles/local/bin/x-open-url.js}
  '';
  claude-notify-waiting = pkgs.writeShellScriptBin "claude-notify-waiting"
    (builtins.readFile ./dotfiles/local/bin/claude-notify-waiting.sh);
  claude-notify-complete = pkgs.writeShellScriptBin "claude-notify-complete"
    (builtins.readFile ./dotfiles/local/bin/claude-notify-complete.sh);
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
  ] ++ lib.optional (riverBackgroundColor != null) pkgs.swaybg ++ [

    # Phase 3: Additional packages
    # tailscale-systray removed - using official `tailscale systray` command

    # From aqua migration (user-level tools)
    pkgs.ghq
    pkgs.git-who
    pkgs.kubectx
    pkgs.stern
    pkgs.just
    pkgs.jnv
    pkgs.lsd
    pkgs.curlie
    pkgs.git-wt
    pkgs.go-readability
    pkgs.mo
    pkgs.n
    pkgs.octorus
    (pkgs.writeShellScriptBin "octorus" ''
      exec ${pkgs.octorus}/bin/or "$@"
    '')

    # GitHub
    llm-agents.copilot-cli

    # Docker
    pkgs.docker-credential-helpers

    (pkgs.writeShellScriptBin "git-wt-hook"
      (builtins.replaceStrings [ "@direnv@" "@mise@" ] [
        (lib.getExe pkgs.direnv)
        (lib.getExe pkgs.mise)
      ] (builtins.readFile ./dotfiles/local/bin/git-wt-hook.sh)))

    (pkgs.writeShellScriptBin "git-wt-deletehook"
      (builtins.readFile ./dotfiles/local/bin/git-wt-deletehook.sh))

    (pkgs.writeShellScriptBin "docker-compose-gc"
      (builtins.replaceStrings [ "@docker@" "@jq@" ] [
        (lib.getExe' pkgs.docker "docker")
        (lib.getExe pkgs.jq)
      ] (builtins.readFile ./dotfiles/local/bin/docker-compose-gc.sh)))

    # Local bin scripts
    (pkgs.writeShellScriptBin "find-parent-package-dir"
      (builtins.replaceStrings [ "@git@" ] [ "${lib.getExe pkgs.git}" ]
        (builtins.readFile ./dotfiles/local/bin/find-parent-package-dir.sh)))

    x-open-url

    claude-notify-waiting
    claude-notify-complete

    (pkgs.writeShellScriptBin "claude-statusline"
      (builtins.readFile ./dotfiles/local/bin/claude-statusline.sh))

    (pkgs.writeShellScriptBin "chrome-debug" (builtins.readFile
      (pkgs.replaceVars ./dotfiles/local/bin/chrome-debug.sh {
        google_chrome = lib.getExe pkgs.google-chrome;
        wl_copy = "${pkgs.wl-clipboard}/bin/wl-copy";
      })))

    (pkgs.writeShellScriptBin "chrome-debug-select-profile" (builtins.readFile
      (pkgs.replaceVars ./dotfiles/local/bin/chrome-debug-select-profile.sh {
        jq = lib.getExe pkgs.jq;
        fzf = lib.getExe pkgs.fzf;
        google_chrome = lib.getExe pkgs.google-chrome;
        wl_copy = "${pkgs.wl-clipboard}/bin/wl-copy";
      })))

    (pkgs.writeShellScriptBin "ndev" ''
      exec nix develop "$HOME/nixos-config" --command "$SHELL"
    '')

    (pkgs.writeShellScriptBin "new-project"
      (builtins.readFile ./dotfiles/local/bin/new-project.sh))

    (pkgs.writeShellScriptBin "save-url-to-doc" (builtins.replaceStrings [
      "@readability@"
      "@git@"
      "@wl_paste@"
      "@sed@"
      "@mkdir@"
      "@mv@"
    ] [
      (lib.getExe pkgs.go-readability)
      (lib.getExe pkgs.git)
      (lib.getExe' pkgs.wl-clipboard "wl-paste")
      (lib.getExe' pkgs.gnused "sed")
      (lib.getExe' pkgs.coreutils "mkdir")
      (lib.getExe' pkgs.coreutils "mv")
    ] (builtins.readFile ./dotfiles/local/bin/save-url-to-doc.sh)))

    (pkgs.writeShellScriptBin "caffeine-toggle"
      (builtins.readFile ./dotfiles/local/bin/caffeine-toggle.sh))

    (pkgs.writeShellScriptBin "caffeine-status"
      (builtins.readFile ./dotfiles/local/bin/caffeine-status.sh))

    (pkgs.writeShellScriptBin "screenrec-toggle" (builtins.readFile
      (pkgs.replaceVars ./dotfiles/local/bin/screenrec-toggle.sh {
        notify_send = lib.getExe' pkgs.libnotify "notify-send";
        slurp = lib.getExe pkgs.slurp;
        wl_screenrec = lib.getExe pkgs.wl-screenrec;
        gdbus = lib.getExe' pkgs.glib "gdbus";
      })))

    (pkgs.writeShellScriptBin "screenrec-status"
      (builtins.readFile ./dotfiles/local/bin/screenrec-status.sh))

    (pkgs.writeShellScriptBin "ralph"
      (builtins.readFile ./dotfiles/local/bin/ralph.sh))

    (pkgs.writeShellScriptBin "himmelblau-status"
      (builtins.readFile ./dotfiles/local/bin/himmelblau-status.sh))

    (pkgs.writeShellScriptBin "git-delete-merged"
      (builtins.replaceStrings [ "@git@" "@git_wt@" ] [
        (lib.getExe pkgs.git)
        (lib.getExe pkgs.git-wt)
      ] (builtins.readFile ./dotfiles/local/bin/git-delete-merged.sh)))

    (pkgs.writeShellScriptBin "tf-pr"
      (builtins.replaceStrings [ "@gh@" "@git@" "@jq@" ] [
        (lib.getExe pkgs.gh)
        (lib.getExe pkgs.git)
        (lib.getExe pkgs.jq)
      ] (builtins.readFile ./dotfiles/local/bin/tf-pr.sh)))

    pkgs.claude-desktop
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
    op_ssh_sign = lib.getExe'
      (osConfig.programs._1password-gui.package or pkgs._1password-gui)
      "op-ssh-sign";
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

  # direnv with nix-direnv integration (Home Manager recommended way)
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = { global.hide_env_diff = true; };
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
      {
        name = "github-copilot-cli-fish";
        src = pkgs.fishPlugins.github-copilot-cli-fish.src;
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

  # Phase 3: fcitx5-cskk辞書設定 (XDG_DATA_HOME, key=value format)
  home.file.".local/share/fcitx5/cskk/dictionary_list".text =
    let inherit (pkgs) skkDictionaries;
    in ''
      type=file,file=$FCITX_CONFIG_DIR/cskk/user.dict,mode=readwrite,encoding=utf-8,complete=true
      type=file,file=${skkDictionaries.l}/share/skk/SKK-JISYO.L,mode=readonly,encoding=euc-jp,complete=false
      type=file,file=${skkDictionaries.emoji}/share/skk/SKK-JISYO.emoji,mode=readonly,encoding=utf-8,complete=true
      type=file,file=${skkDictionaries.zipcode}/share/skk/SKK-JISYO.zipcode,mode=readonly,encoding=euc-jp,complete=false
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
  xdg.configFile."waybar/style.css".source = ./dotfiles/waybar/style.css;
  xdg.configFile."swaylock/config".source = let
    lockColor = if riverBackgroundColor != null then
      builtins.replaceStrings [ "#" ] [ "" ] riverBackgroundColor
    else
      "232136";
    configContent = builtins.replaceStrings [ "@lock_color@" ] [ lockColor ]
      (builtins.readFile ./dotfiles/swaylock/config);
  in pkgs.writeText "swaylock-config" configContent;
  # hypridle - idle management (works with both Hyprland and River)
  services.hypridle = {
    enable = true;
    systemdTarget = "river-session.target";
    settings = let
      lockTimeout = if variant == "laptop" then 300 else 900;
      screenOffTimeout = if variant == "laptop" then 420 else 1800;
      suspendTimeout = if variant == "laptop" then 1800 else 48 * 60 * 60;
    in {
      general = {
        lock_cmd =
          "${pkgs.procps}/bin/pidof swaylock || ${pkgs.swaylock-effects}/bin/swaylock -f --grace 10";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "${pkgs.wlopm}/bin/wlopm --on '*'";
      };
      listener = [
        {
          timeout = lockTimeout;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = screenOffTimeout;
          on-timeout = "${pkgs.wlopm}/bin/wlopm --off '*'";
          on-resume = "${pkgs.wlopm}/bin/wlopm --on '*'";
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
  xdg.configFile."xdg-terminals.list".text = ''
    Alacritty.desktop
  '';
  home.file.".local/share/applications/Alacritty.desktop".text = ''
    [Desktop Entry]
    Type=Application
    TryExec=alacritty
    Exec=alacritty
    Icon=Alacritty
    Terminal=false
    Categories=System;TerminalEmulator;
    Name=Alacritty
    GenericName=Terminal
    Comment=A fast, cross-platform, OpenGL terminal emulator
    StartupNotify=true
    StartupWMClass=Alacritty
    X-TerminalArgExec=-e
    X-TerminalArgAppId=--class
    X-TerminalArgTitle=-T
    X-TerminalArgDir=--working-directory
    X-TerminalArgHold=--hold
  '';
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
  xdg.desktopEntries.screenrec-toggle = {
    name = "Toggle Screen Recording";
    comment = "Start or stop screen recording with wl-screenrec";
    exec = "screenrec-toggle";
    terminal = false;
    categories = [ "AudioVideo" "Utility" ];
  };

  # Override figma-linux desktop file to declare the figma:// URI scheme
  # (upstream package omits MimeType, so xdg-desktop-portal cannot resolve callbacks)
  xdg.desktopEntries.figma-linux = {
    name = "Figma Linux";
    comment = "Unofficial Figma desktop application for Linux";
    exec = "figma-linux %U";
    icon = "figma-linux";
    mimeType = [ "x-scheme-handler/figma" ];
    terminal = false;
  };

  xdg.desktopEntries.x-open-url = {
    name = "Web Browser Chooser";
    comment = "Browse the web";
    exec = "${lib.getExe x-open-url} %u";
    mimeType = [ "x-scheme-handler/http" "x-scheme-handler/https" ];
    categories = [ "Network" "WebBrowser" ];
    terminal = false;
    startupNotify = false;
  };

  # Override Zen Browser desktop file with full path (for xdg-desktop-portal)
  xdg.desktopEntries.zen = {
    name = "Zen Browser";
    genericName = "Web Browser";
    exec = "${lib.getExe zenBrowser} --name zen %U";
    icon = "zen";
    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "application/vnd.mozilla.xul+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    categories = [ "Network" "WebBrowser" ];
    terminal = false;
    startupNotify = true;
    settings.StartupWMClass = "zen";
    actions = {
      new-private-window = {
        name = "New Private Window";
        exec = "${lib.getExe zenBrowser} --private-window %U";
      };
      new-window = {
        name = "New Window";
        exec = "${lib.getExe zenBrowser} --new-window %U";
      };
      profile-manager-window = {
        name = "Profile Manager";
        exec = "${lib.getExe zenBrowser} --ProfileManager";
      };
    };
  };

  # Disable tray applets autostart (using TUI wrappers via waybar instead)
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  xdg.configFile."autostart/1password.desktop".text = ''
    [Desktop Entry]
    Name=1Password
    Exec=1password --silent
    Terminal=false
    Type=Application
  '';

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

  # Codex CLI: AGENTS.md (share same source as CLAUDE.md)
  home.file.".codex/AGENTS.md".source = ./dotfiles/claude/CLAUDE.md;

  # jai (Jail for AI) config files
  home.file.".jai/default.conf".source = ./dotfiles/jai/default.conf;

  # Agents/Codex Skills (copy as real files, not symlinks)
  home.activation.agentsSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    skills_dir="$HOME/.agents/skills"
    mkdir -p "$skills_dir"

    # Managed skills: remove and re-copy each individually to preserve unmanaged skills
    managed_skills="save-url-to-doc code-reviewer simplify commit commit-push commit-push-pr pr-comments organize-commits opsx-run"
    for s in $managed_skills; do
      rm -rf "$skills_dir/$s"
    done

    # Shared skills (from agents/skills)
    cp -rL ${
      ./dotfiles/agents/skills/save-url-to-doc
    } "$skills_dir/save-url-to-doc"
    cp -rL ${./dotfiles/agents/skills/opsx-run} "$skills_dir/opsx-run"
    cp -rL ${./dotfiles/agents/skills/commit} "$skills_dir/commit"
    cp -rL ${./dotfiles/agents/skills/commit-push} "$skills_dir/commit-push"
    cp -rL ${./dotfiles/agents/skills/pr-comments} "$skills_dir/pr-comments"
    cp -rL ${
      ./dotfiles/agents/skills/commit-push-pr
    } "$skills_dir/commit-push-pr"
    cp -rL ${
      ./dotfiles/agents/skills/organize-commits
    } "$skills_dir/organize-commits"

    # Codex-only skills
    cp -rL ${./dotfiles/codex/skills/code-reviewer} "$skills_dir/code-reviewer"
    cp -rL ${./dotfiles/codex/skills/simplify} "$skills_dir/simplify"
    cp -rL ${
      ./dotfiles/codex/skills/frontend-design
    } "$skills_dir/frontend-design"

    chmod -R u+w "$skills_dir"

    # Claude Code: symlink ~/.claude/skills/<name> -> ~/.agents/skills/<name>
    claude_skills_dir="$HOME/.claude/skills"
    mkdir -p "$claude_skills_dir"
    claude_managed_skills="save-url-to-doc commit commit-push commit-push-pr organize-commits opsx-run pr-comments"
    for s in $claude_managed_skills; do
      rm -rf "$claude_skills_dir/$s"
      ln -s "$skills_dir/$s" "$claude_skills_dir/$s"
    done
  '';

  # Phase 0: Claude settings.local.json (inline management with stop hook)
  home.file.".claude/settings.local.json".text = builtins.toJSON {
    autoUpdaterStatus = "disabled";
    outputStyle = "default";
    env = { "ENABLE_TOOL_SEARCH" = "true"; };
    hooks = {
      Stop = [{
        matcher = "";
        hooks = [
          {
            type = "command";
            command =
              "paplay /run/current-system/sw/share/sounds/freedesktop/stereo/bell.oga";
          }
          {
            type = "command";
            command = lib.getExe claude-notify-complete;
          }
        ];
      }];
      Notification = [{
        matcher = "";
        hooks = [{
          type = "command";
          command = lib.getExe claude-notify-waiting;
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
    source = let
      swaybgSpawn = if riverBackgroundColor != null then
        ''riverctl spawn "swaybg -c '${riverBackgroundColor}'"''
      else
        "# No background color configured (using default)";
      initContent = builtins.readFile ./dotfiles/river/init;
    in pkgs.writeShellScript "river-init"
    (builtins.replaceStrings [ "@swaybg_spawn@" ] [ swaybgSpawn ] initContent);
    executable = true;
  };

  # Kanshi - auto display configuration for River
  xdg.configFile."kanshi/config".source = if variant == "laptop" then
    pkgs.replaceVars ./dotfiles/kanshi/config-laptop {
      makoctl = "${pkgs.mako}/bin/makoctl";
    }
  else
    ./dotfiles/kanshi/config-${variant};

  programs.firefox = {
    enable = true;
    nativeMessagingHosts = [ pkgs.tridactyl-native ]
      ++ lib.optional hasHimmelblau himmelblauPkg;
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

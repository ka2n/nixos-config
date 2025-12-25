{ config, pkgs, inputs, ... }: {
  home.stateVersion = "25.11";

  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nix-index-database.comma.enable = true;

  programs.firefox = {
    enable = true;
    package = pkgs.wrapFirefox
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.zen-browser-unwrapped {
        pname = "zen-browser";
        extraPolicies = {
          ExtensionSettings = {
            "linux-entra-sso@example.com" = {
              install_url = "https://github.com/siemens/linux-entra-sso/releases/download/v1.7.1/linux_entra_sso-1.7.1.xpi";
              installation_mode = "normal_installed";
            };
          };
        };
      };
    configPath = ".zen";

    profiles.default = {
      isDefault = true;
      settings = {
        # Zen Browser specific
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

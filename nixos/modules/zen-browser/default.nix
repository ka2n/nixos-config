{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.programs.zen-browser;
  zenUnwrapped = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.zen-browser-unwrapped;
in
{
  options.programs.zen-browser = {
    enable = lib.mkEnableOption "Zen Browser";

    nativeMessagingHosts = {
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Native messaging host packages for Zen Browser";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.wrapFirefox zenUnwrapped {
        pname = "zen-browser";
        nativeMessagingHosts = cfg.nativeMessagingHosts.packages;
        # Enable system-wide native messaging hosts directory
        hasMozSystemDirPatch = true;
      })
    ];
  };
}

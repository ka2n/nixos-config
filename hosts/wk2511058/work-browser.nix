{ config, lib, pkgs, ... }:

{
  options.local.workBrowser.enable = lib.mkEnableOption "Work browser policies after manual certificate setup";

  config = lib.mkMerge [
    {
      local.workBrowser.enable = true;
      environment.systemPackages = [ pkgs.nssTools ];
    }
    (lib.mkIf config.local.workBrowser.enable {
      sops.secrets = lib.genAttrs [ "work-browser-chrome-policy" "work-browser-edge-policy" ] (name: {
        sopsFile = ../../secrets/wk2511058/work-browser-policy.enc;
        format = "binary";
        path = "/etc/opt/${if name == "work-browser-chrome-policy" then "chrome" else "edge"}/policies/managed/work-browser.json";
        mode = "0444";
      });
    })
  ];
}

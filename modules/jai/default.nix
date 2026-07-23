{ config, lib, pkgs, ... }:

let
  cfg = config.programs.jai;
in
{
  options.programs.jai = {
    enable = lib.mkEnableOption "jai - Jail for AI sandboxing tool";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.jai.override { inherit (cfg) untrustedUser; };
      defaultText = lib.literalExpression "pkgs.jai.override { inherit (cfg) untrustedUser; }";
      description = "The jai package to install.";
    };

    untrustedUser = lib.mkOption {
      type = lib.types.str;
      default = "_jai";
      description = "Username for the sandboxed untrusted user.";
    };
  };

  config = lib.mkIf cfg.enable {
    security.wrappers.jai = {
      source = "${cfg.package}/bin/jai";
      owner = "root";
      group = "root";
      setuid = true;
    };

    users.users.${cfg.untrustedUser} = {
      isSystemUser = true;
      group = cfg.untrustedUser;
      # jai (jai.cc:118) only accepts the untrusted user when GECOS equals
      # "JAI sandbox untrusted user" AND home is exactly "/". Both are required
      # for strict mode; otherwise jai warns and silently degrades to the
      # invoking user (no privilege drop).
      description = "JAI sandbox untrusted user";
      home = "/";
      shell = "${pkgs.shadow}/bin/nologin";
    };

    users.groups.${cfg.untrustedUser} = {};
  };
}

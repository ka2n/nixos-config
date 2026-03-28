{ config, lib, pkgs, ... }:

let
  cfg = config.programs.jai;
in
{
  options.programs.jai = {
    enable = lib.mkEnableOption "jai - Jail for AI sandboxing tool";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.jai;
      defaultText = lib.literalExpression "pkgs.jai";
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
      description = "JAI sandbox untrusted user";
      home = "/nonexistent";
      shell = "/usr/sbin/nologin";
    };

    users.groups.${cfg.untrustedUser} = {};
  };
}

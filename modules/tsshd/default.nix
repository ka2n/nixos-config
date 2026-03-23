{ config, lib, pkgs, ... }:

let
  cfg = config.programs.tsshd;
in
{
  options.programs.tsshd = {
    enable = lib.mkEnableOption "tsshd - trzsz SSH daemon over UDP";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tsshd;
      defaultText = lib.literalExpression "pkgs.tsshd";
      description = "The tsshd package to install.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open UDP ports for tsshd in the firewall.";
    };

    portRange = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = { from = 61001; to = 61999; };
      description = "UDP port range for tsshd.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    networking.firewall.allowedUDPPortRanges =
      lib.mkIf cfg.openFirewall [ cfg.portRange ];
  };
}

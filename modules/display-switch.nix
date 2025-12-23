{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.display-switch;
in {
  options.services.display-switch = {
    enable = mkEnableOption "display-switch automatic DDC display switcher";

    config = mkOption {
      type = types.lines;
      default = "";
      description = "Configuration for display-switch (display-switch.ini content)";
      example = ''
        usb_device = "05e3:0626"
        on_usb_connect = "Hdmi1"
        on_usb_disconnect = "Hdmi2"
      '';
    };
  };

  config = mkIf cfg.enable {
    # Install the package
    environment.systemPackages = [ pkgs.display-switch ];

    # Load required kernel modules
    boot.kernelModules = [ "i2c_dev" ];

    # Create i2c group
    users.groups.i2c = {};

    # udev rules for i2c device access
    services.udev.extraRules = ''
      # Assigns the i2c devices to group i2c, and gives that group RW access:
      KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
    '';

    # Configuration file
    environment.etc."display-switch/display-switch.ini".text = cfg.config;

    # systemd service
    systemd.services.display-switch = {
      description = "display-switch automatic DDC display switcher";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        StandardOutput = "journal";
        Restart = "always";

        # Use dynamic user with i2c group access
        DynamicUser = true;
        SupplementaryGroups = "i2c";

        LogsDirectory = "display-switch";
        StateDirectory = "display-switch";

        # Set HOME for display_switch to find config
        Environment = "HOME=/var/lib/display-switch";

        # Setup config and log directory structure
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p /var/lib/display-switch/.config/display-switch"
          "${pkgs.coreutils}/bin/ln -sf /etc/display-switch/display-switch.ini /var/lib/display-switch/.config/display-switch/display-switch.ini"
          "${pkgs.coreutils}/bin/mkdir -p /var/lib/display-switch/.local/share/"
          "${pkgs.coreutils}/bin/ln -sf /var/log/display-switch /var/lib/display-switch/.local/share/display-switch"
        ];

        ExecStart = "${pkgs.display-switch}/bin/display_switch";
      };
    };
  };
}

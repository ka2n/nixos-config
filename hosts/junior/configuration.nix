# Desktop-specific configuration
{ config, pkgs, pkgs-unstable, lib, inputs, llm-agents, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../common
    ../../modules/display-switch.nix
    ../../modules/display/dell-s2722qc-edid.nix
    ../../modules/hardware/amdgpu-polaris.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "junior";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs pkgs-unstable llm-agents;
      variant = "desktop";
      riverBackgroundColor = "#c79081";
    };
    users.k2 = import ../../home/default.nix;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = ["ntfs"];

  environment.systemPackages = with pkgs; [
    foot
    ntfs3g
    darktable
    shotwell
  ];

  # Display manager (greetd+tuigreet - Wayland native, lightweight TUI)
  services.greetd = {
    enable = true;
    settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
  };
  security.pam.services.greetd.enableGnomeKeyring = true;

  # AMD Polaris GPU fixes
  hardware.amdgpu.polaris.enable = true;

  # Enable display-switch service
  services.display-switch = {
    enable = true;
    config = ''
      ## USB device to watch for to trigger screen change
      usb_device = "05e3:0610"

      ## Specify which input to switch for _all_ DDC monitors.
      on_usb_connect = "Hdmi1"
      on_usb_disconnect = "Hdmi2"
    '';
  };

  fileSystems =
    let
      ntfs-drives = [
        "/data"
      ];
    in
    lib.genAttrs ntfs-drives (path: {
      options = [
        "uid=1000"
	"nofail"
      ];
    });

  # Force RGB output for HDMI (DELL S2722QC)
  hardware.display.dellS2722qcRgb.enable = true;
  hardware.display.outputs."HDMI-A-1".edid = config.hardware.display.dellS2722qcRgb.edidFilename;

  # Webcam flicker prevention (50Hz for East Japan)
  hardware.webcam.flickerPrevention = {
    enable = true;
    devices = {
      "Logitech StreamCam" = 50;
    };
  };

  # Power button behavior
  services.logind.settings.Login.HandlePowerKey = "suspend";

  system.stateVersion = "25.11";
}

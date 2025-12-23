# Desktop-specific configuration
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../common
    ../../modules/display-switch.nix
  ];

  networking.hostName = "junior";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = ["ntfs"];

  environment.systemPackages = with pkgs; [
    foot
    ntfs3g
  ];

  # Enable display-switch service
  services.display-switch = {
    enable = true;
    config = ''
      ## USB device to watch for to trigger screen change
      usb_device = "05e3:0626"

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
  
  systemd.services.amdgpu-power = {
    description = "AMD GPU Power Management";
    wantedBy = ["multi-user.target"];
    after = ["display-manager.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      sleep 2
      for gpu in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        [ -w "$gpu" ] && echo "high" > "$gpu"
      done
      for gpu in /sys/class/drm/card*/device/power_dpm_state; do
        [ -w "$gpu" ] && echo "performance" > "$gpu"
      done
    '';
  };

  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
    "amdgpu.gpu_recovery=1"
  ];

  system.stateVersion = "25.11";
}

# Desktop-specific configuration
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../common
    ../../modules/display-switch.nix
    ../../modules/display/dell-s2722qc-edid.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "junior";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; variant = "desktop"; himmelblauPkg = null; };
    users.k2 = import ../../home/default.nix;
  };

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
  
  # AMD GPU Power Management - Memory Clock Locking
  # Fix artifacts by locking memory clock (mclk) to highest level only
  # GPU clock (sclk) remains dynamic for better power efficiency
  # Root cause: Memory speed unable to keep up with screen refresh rates
  # Note: udev rule re-applies settings after GPU reset events
  systemd.services.amdgpu-power = {
    description = "AMD GPU Power Management - Lock Memory Clock";
    wantedBy = ["multi-user.target"];
    after = ["display-manager.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      sleep 2
      # Set to manual mode to allow individual clock control
      for gpu in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        [ -w "$gpu" ] && echo "manual" > "$gpu"
      done
      # Lock memory clock to highest level (level 2 for this GPU: 1750MHz)
      # This prevents artifacts while keeping GPU clock dynamic
      for mclk in /sys/class/drm/card*/device/pp_dpm_mclk; do
        if [ -w "$mclk" ]; then
          echo "2" > "$mclk"
        fi
      done
    '';
  };

  # Reapply AMD GPU settings after GPU reset events
  services.udev.extraRules = ''
    # Trigger on AMD GPU changes (after reset, resume, etc.)
    ACTION=="change", KERNEL=="card[0-9]", SUBSYSTEM=="drm", ATTR{device/vendor}=="0x1002", RUN+="${pkgs.systemd}/bin/systemctl restart --no-block amdgpu-power.service"
  '';

  # AMD GPU Power Management for Polaris (RX 480/570/580)
  # Known issue: GFXOFF feature causes artifacts and crashes on Polaris cards
  # Solution: Disable GFXOFF (bit 15) while keeping other power-saving features
  # Sources:
  # - https://wiki.archlinux.org/title/AMDGPU
  # - https://wiki.gentoo.org/wiki/AMDGPU
  # - https://docs.kernel.org/gpu/amdgpu/thermal.html
  # - https://github.com/mohemohe/linux-amdgpu-artifacts-fix
  # - https://github.com/sibradzic/amdgpu-clocks
  # - https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/include/amd_shared.h
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffff7fff"  # Disable PP_GFXOFF_MASK (bit 15) only
    "amdgpu.gpu_recovery=1"
    "amdgpu.runpm=0"  # Disable runtime PM - fixes BACO suspend/resume crashes on Polaris
    "amdgpu.noretry=0"  # Enable retry on timeout (may help with fence timeouts)
  ];

  # Hyprland environment variables for AMD GPU stability
  # Disable explicit sync on Polaris (known to cause crashes)
  environment.sessionVariables = {
    WLR_DRM_NO_ATOMIC = "1";  # Disable atomic modesetting (reduces fence timeouts)
  };

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

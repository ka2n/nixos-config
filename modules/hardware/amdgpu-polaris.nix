{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.amdgpu.polaris;
in {
  options.hardware.amdgpu.polaris = {
    enable = mkEnableOption "AMD Polaris GPU (RX 480/570/580) fixes and optimizations";

    enableSuspendFix = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable VRAM eviction before suspend to prevent crashes.
        Polaris GPUs crash on resume if VRAM cannot be saved to RAM (OOM during eviction).
        This forces VRAM eviction before suspend, allowing swap usage if needed.
      '';
    };

    enableMemoryClockFix = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Lock memory clock to highest level to prevent artifacts.
        Root cause: Memory speed unable to keep up with screen refresh rates.
        GPU clock (sclk) remains dynamic for better power efficiency.
      '';
    };

    suspendStabilizationDelay = mkOption {
      type = types.int;
      default = 3;
      description = "Seconds to wait for GPU to stabilize after resume";
    };

    memoryClockInitDelay = mkOption {
      type = types.int;
      default = 2;
      description = "Seconds to wait before applying memory clock settings";
    };
  };

  config = mkIf cfg.enable {
    # Enable kernel debugfs for amdgpu_evict_vram access
    boot.kernel.sysctl."kernel.sysrq" = 1;  # Enable SysRq for emergency recovery

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
      "amdgpu.bapm=0"   # Disable Bidirectional Application Power Management
      "amdgpu.aspm=0"   # Disable PCIe Active State Power Management
      "amdgpu.noretry=0"  # Enable retry on timeout (may help with fence timeouts)
      "amdgpu.lockup_timeout=30000"  # Increase timeout from 10s to 30s for heavy workloads
    ];

    # Hyprland environment variables for AMD GPU stability
    # Disable explicit sync on Polaris (known to cause crashes)
    environment.sessionVariables = {
      WLR_DRM_NO_ATOMIC = "1";  # Disable atomic modesetting (reduces fence timeouts)
    };

    # AMD GPU Power Management - Memory Clock Locking
    # Fix artifacts by locking memory clock (mclk) to highest level only
    # GPU clock (sclk) remains dynamic for better power efficiency
    # Root cause: Memory speed unable to keep up with screen refresh rates
    # Note: udev rule re-applies settings after GPU reset events
    systemd.services.amdgpu-power = mkIf cfg.enableMemoryClockFix {
      description = "AMD GPU Power Management - Lock Memory Clock";
      wantedBy = ["multi-user.target"];
      after = ["display-manager.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        sleep ${toString cfg.memoryClockInitDelay}
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
    services.udev.extraRules = mkIf cfg.enableMemoryClockFix ''
      # Trigger on AMD GPU changes (after reset, resume, etc.)
      ACTION=="change", KERNEL=="card[0-9]", SUBSYSTEM=="drm", ATTR{device/vendor}=="0x1002", RUN+="${pkgs.systemd}/bin/systemctl restart --no-block amdgpu-power.service"
    '';

    # AMD GPU VRAM Eviction before Suspend
    # Polaris GPUs crash on resume if VRAM cannot be saved to RAM (OOM during eviction)
    # This service forces VRAM eviction before suspend, allowing swap usage if needed
    # Source: https://nyanpasu64.gitlab.io/blog/amdgpu-sleep-wake-hang/
    systemd.services.amdgpu-suspend = mkIf cfg.enableSuspendFix {
      description = "AMD GPU suspend preparation";
      before = ["sleep.target"];
      wantedBy = ["sleep.target"];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        # Sync filesystem to prevent data loss
        sync

        # Drop caches to free up RAM for VRAM eviction
        echo 3 > /proc/sys/vm/drop_caches

        # Evict VRAM to system RAM for each AMD GPU
        # Reading this debugfs file triggers the driver to move VRAM contents to RAM
        for evict in /sys/kernel/debug/dri/*/amdgpu_evict_vram; do
          if [ -r "$evict" ]; then
            cat "$evict" > /dev/null 2>&1 || true
          fi
        done
      '';
    };

    # Restore AMD GPU settings after resume
    systemd.services.amdgpu-resume = mkIf cfg.enableSuspendFix {
      description = "AMD GPU resume restoration";
      after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
      wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        # Wait for GPU to stabilize after resume
        sleep ${toString cfg.suspendStabilizationDelay}
        # Restart amdgpu-power to reapply memory clock settings
        ${optionalString cfg.enableMemoryClockFix "${pkgs.systemd}/bin/systemctl restart amdgpu-power.service || true"}
      '';
    };
  };
}

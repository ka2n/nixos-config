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
        Lock GPU performance to highest level to prevent artifacts and crashes.
        Uses power_dpm_force_performance_level=high to lock both GPU and memory clocks.
        Also sets power_dpm_state=performance for additional stability.
        Historically confirmed effective on this hardware (ArchLinux 2022-2023).
      '';
    };

    enableVendorReset = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Load the vendor-reset kernel module to fix GPU resets on Polaris.
        The mainline kernel falls back to PCI CONFIG reset for Polaris (GFX8)
        because BACO is not supported; this reset method is unreliable and
        often hangs the entire system. vendor-reset implements the device-specific
        POLARIS10 reset sequence that actually works.
        Must be loaded in initrd so it is available before amdgpu attempts a reset.
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
    # Kernel watchdog / panic settings for auto-reboot on hard freeze
    # Polaris GPU hangs leave D-state tasks blocked on GPU fences (not CPU interrupt stall),
    # so hung_task_panic is the critical setting for this failure mode.
    boot.kernel.sysctl = {
      "kernel.sysrq" = 1;              # Enable SysRq for emergency recovery
      "kernel.hardlockup_panic" = 1;   # Panic on CPU hard lockup (NMI watchdog)
      "kernel.softlockup_panic" = 1;   # Panic on CPU soft lockup
      "kernel.hung_task_panic" = 1;    # Panic on D-state task hang (GPU fence wait)
      "kernel.panic_on_oops" = 1;      # Turn kernel oops into panic (enables auto-reboot)
      "kernel.nmi_watchdog" = 1;       # Enable NMI watchdog for hard lockup detection
      # hung_task_timeout_secs kept at default (120s) to avoid false positives during NixOS builds
    };

    # AMD GPU kernel parameters for Polaris (RX 480/570/580)
    # Sources:
    # - https://wiki.archlinux.org/title/AMDGPU
    # - https://docs.kernel.org/gpu/amdgpu/module-parameters.html
    # - https://gitlab.freedesktop.org/drm/amd/-/issues/4765 (kernel 6.18.x CWSR bug)
    # - https://gitlab.freedesktop.org/drm/amd/-/issues/226 (gmc_v8_0 hung / VM fault)
    # - external-docs/consolidated/amd-polaris-rx480-gpu-crash-fixes.md
    boot.kernelParams = [
      # --- Auto-reboot after panic ---
      # Reboot 10 seconds after kernel panic (gives time to see the message)
      "panic=10"

      # --- Power feature mask ---
      # Disable: PP_GFXOFF_MASK (bit 15), PP_STUTTER_MODE (bit 17), PP_OVERDRIVE_MASK (bit 14)
      # GFXOFF causes artifacts/crashes; STUTTER_MODE causes display issues;
      # Overdrive unused (eliminates "Overdrive is enabled" warning)
      "amdgpu.ppfeaturemask=0xfffd3fff"

      # --- VM / page table ---
      # Force CPU-based GPUVM page table updates instead of GPU-based
      # ArchWiki recommended fix for VM_CONTEXT1_PROTECTION_FAULT on GCN (gmc_v8_0)
      "amdgpu.vm_update_mode=3"

      # --- Compute ---
      # Disable Compute Wave Save/Restore - workaround for kernel 6.18.x CWSR bug
      # that causes MES ring buffer saturation and GPU reset loops
      "amdgpu.cwsr_enable=0"

      # --- Reset / recovery ---
      "amdgpu.gpu_recovery=1"
      # reset_method=1 is not supported on Polaris (GFX8); kernel falls back to AUTO (PCI CONFIG).
      # Removed to eliminate log noise: "Specified reset method:1 isn't supported, using AUTO instead"

      # --- Power management ---
      "amdgpu.runpm=0"   # Disable runtime PM - fixes BACO suspend/resume crashes
      "amdgpu.bapm=0"    # Disable Bidirectional Application Power Management
      "amdgpu.aspm=0"    # Disable driver-level PCIe ASPM
      "pcie_aspm=off"    # Disable system-wide PCIe ASPM (more thorough than amdgpu.aspm=0)

      # --- Display ---
      "amdgpu.sg_display=0"      # Disable scatter/gather display (prevents display-related VM faults)
      "amdgpu.dcdebugmask=0x10"  # Workaround for flip_done timeout
    ];

    # vendor-reset: device-specific GPU reset for Polaris (GFX8)
    # Replaces the broken PCI CONFIG reset fallback with the proper POLARIS10 reset sequence.
    # Must be in initrd so it intercepts amdgpu resets as early as possible.
    # Source: https://github.com/gnif/vendor-reset
    boot.extraModulePackages = mkIf cfg.enableVendorReset [
      config.boot.kernelPackages.vendor-reset
    ];
    boot.initrd.kernelModules = mkIf cfg.enableVendorReset [ "vendor-reset" ];

    # Hardware watchdog integration via sp5100-tco (AMD TCO watchdog, present on this system)
    # systemd kicks the watchdog every runtimeTime; if it stops (frozen), hardware reboots at rebootTime.
    systemd.watchdog.runtimeTime = "60s";
    systemd.watchdog.rebootTime = "3min";

    # Wayland environment variables for AMD GPU stability
    environment.sessionVariables = {
      WLR_DRM_NO_ATOMIC = "1";  # Disable atomic modesetting (reduces fence timeouts)
    };

    # AMD GPU Power Management - Lock to High Performance
    # Lock both GPU core clock (sclk) and memory clock (mclk) to highest levels.
    # This prevents clock transition instability that causes VM faults and crashes.
    # Historically confirmed effective on this hardware (ArchLinux 2022-2023).
    # Note: udev rule re-applies settings after GPU reset events
    systemd.services.amdgpu-power = mkIf cfg.enableMemoryClockFix {
      description = "AMD GPU Power Management - Lock High Performance";
      wantedBy = ["multi-user.target"];
      after = ["display-manager.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        sleep ${toString cfg.memoryClockInitDelay}
        for card_node in /sys/class/drm/card[0-9]*; do
          # Skip connector entries like card1-DP-1 (only process cardN bare devices)
          case "$(basename "$card_node")" in card*[!0-9]*) continue ;; esac
          card="$card_node/device"
          [ -d "$card" ] || continue
          # Set DPM state to performance (may fail if GPU is in reset)
          # Use subshell so bash's own redirection errors are suppressed, not just echo's stderr
          ( echo "performance" > "$card/power_dpm_state" ) 2>/dev/null || true
          # Lock GPU and memory clocks to highest level
          ( echo "high" > "$card/power_dpm_force_performance_level" ) 2>/dev/null || true
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

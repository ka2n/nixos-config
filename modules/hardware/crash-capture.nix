{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.crashCapture;
in {
  options.hardware.crashCapture = {
    enable = mkEnableOption "kernel crash log capture via ramoops (pstore RAM backend)";

    ramoops = {
      memAddress = mkOption {
        type = types.str;
        default = "0xb0000000";
        description = ''
          Physical start address of the RAM region reserved for ramoops.
          Must sit inside a region the firmware reports as "System RAM" in e820.
          On junior the low System RAM block is 0x0a214000-0xcaa70fff, so 0xb0000000
          (2.75 GiB) is comfortably inside it and clear of the low BIOS area.
          Verify with: dmesg | grep "BIOS-e820.*System RAM"
        '';
      };

      memSize = mkOption {
        type = types.str;
        default = "0x1000000"; # 16 MiB
        description = "Size of the reserved ramoops region, in bytes (memparse syntax).";
      };

      recordSize = mkOption {
        type = types.str;
        default = "0x20000"; # 128 KiB
        description = ''
          Size of a single dump record. memSize / recordSize = number of retained
          crash records (16 MiB / 128 KiB = 128), which then wrap oldest-first.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    # Why ramoops and not efi_pstore:
    # efi_pstore is built in and registers automatically, but on this board it has
    # written nothing across ~10 unclean resets (/sys/fs/pstore empty and
    # systemd-pstore.service has never run). Writing EFI variables from panic context
    # is unreliable on consumer AM4 firmware. ramoops writes to plain reserved DRAM
    # with no firmware involvement.
    #
    # pstore supports exactly ONE backend at a time (pstore_register() refuses a
    # second registration), and efi_pstore wins the race because it is built in.
    # pstore.backend=ramoops is therefore required, and it does mean efi_pstore is
    # given up - an acceptable trade since it has never produced a record here.
    boot.kernelParams = [
      # Carve the region out of e820 so nothing else allocates it.
      ("memmap=" + cfg.ramoops.memSize + "$" + cfg.ramoops.memAddress)

      "pstore.backend=ramoops"

      "ramoops.mem_address=${cfg.ramoops.memAddress}"
      "ramoops.mem_size=${cfg.ramoops.memSize}"
      "ramoops.record_size=${cfg.ramoops.recordSize}"

      # 16-byte Reed-Solomon ECC per record. Also acts as a corruption detector:
      # if the board re-trains memory on reset the records fail to validate rather
      # than coming back as plausible garbage.
      "ramoops.ecc=1"

      # 1=Panic, 2=Oops (default), 3=Emergency. 3 also catches emergency restarts.
      # Deliberately not 4 (Shutdown): that would dump on every clean shutdown and
      # push real crash records out of the ring.
      "ramoops.max_reason=3"
    ];

    # Load in initrd so early panics are captured too.
    boot.initrd.kernelModules = [ "ramoops" ];

    # systemd-pstore.service (enabled by default) moves records out of /sys/fs/pstore
    # into /var/lib/systemd/pstore on boot, so they survive later crashes.
    # NOTE: this means a fresh crash shows up in /var/lib/systemd/pstore, not
    # /sys/fs/pstore, by the time you log in.
  };
}

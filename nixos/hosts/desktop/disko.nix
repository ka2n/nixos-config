# Disko configuration for desktop
{ ... }:
{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-id/nvme-WD_BLACK_SN770_2TB_22322X800177";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-L" "nixos" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                };
              };
            };
          };
        };
      };
      swap = {
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZALQ128HBHQ-000L1_S4YFNF0MC25681";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            swap = {
              size = "100%";
              content = {
                type = "swap";
                extraArgs = [ "-L" "swap" ];
                resumeDevice = true;
              };
            };
          };
        };
      };
    };
  };
}

# Patched EDID for DELL S2722QC monitor
# Forces RGB output instead of YCbCr on AMD GPUs (junior)
# Changes from original:
#   - Removed DC_Y444 flag (HDMI VSDB byte 6: 0x38 -> 0x30)
#   - Removed YCbCr 4:2:0 Capability Map Data Block
#   - Added Video Capability Data Block (VCDB) with QS=1 (RGB Quantization Selectable)
#   - Fixed Block 1 checksum
{ config, pkgs, lib, ... }:

let
  edidFilename = "dell-s2722qc-rgb.bin";
in
{
  options.hardware.display.dellS2722qcRgb = {
    enable = lib.mkEnableOption "patched EDID for DELL S2722QC to force RGB output";
    edidFilename = lib.mkOption {
      type = lib.types.str;
      default = edidFilename;
      readOnly = true;
      description = "Filename of the patched EDID in /lib/firmware/edid/";
    };
  };

  config = lib.mkIf config.hardware.display.dellS2722qcRgb.enable {
    hardware.display.edid.packages = [
      (pkgs.runCommand "edid-dell-s2722qc-rgb" {} ''
        mkdir -p $out/lib/firmware/edid
        base64 -d > "$out/lib/firmware/edid/${edidFilename}" <<'EOF'
AP///////wAQrNahQjQ3MQ4gAQOAPCJ46lCVqFROpSYPUFSlSwBxT4GAqcCpQNHA4QABAQEBCOgAMPJwWoCwWIoAVVAhAAAeAAAA/wA4RlFTTEQzCiAgICAgAAAA/ABERUxMIFMyNzIyUUMKAAAA/QAYTAqJPAAKICAgICAgAQcCA1HBVWEBAgMEBQYHEBESExQVFh8gIV1eXyMJBweDAQAAbQMMABAAMEQgAGADAgFn2F3EAXiAAeIAwAAA4wXAAOYGBQFaWgBoGgAAAQEoPOZWXgCgoKApUDAgNQBVUCEAABoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASg==
EOF
      '')
    ];
  };
}

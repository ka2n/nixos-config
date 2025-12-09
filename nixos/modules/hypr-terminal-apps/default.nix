{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hypr-terminal-apps;

  mkWrapper = name: command: pkgs.writeShellScriptBin "hypr-${name}" ''
    exec ${pkgs.alacritty}/bin/alacritty --class ${name} -e ${command}
  '';

  mkDesktopFile = { name, displayName, genericName, comment, icon ? null, categories ? [ "Utility" ] }: pkgs.makeDesktopItem {
    inherit name comment categories genericName;
    desktopName = displayName;
    exec = "hypr-${name}";
    terminal = false;
    icon = icon;
  };

  bluetuiWrapper = mkWrapper "bluetui" "${pkgs.bluetui}/bin/bluetui";
  wiremixWrapper = mkWrapper "wiremix" "${pkgs.wiremix}/bin/wiremix";
  clipseWrapper = mkWrapper "clipse" "${pkgs.clipse}/bin/clipse";

  bluetuiDesktop = mkDesktopFile {
    name = "bluetui";
    displayName = "Bluetui";
    genericName = "Bluetooth Manager";
    comment = "TUI application for managing bluetooth devices";
    categories = [ "Utility" "Settings" ];
  };

  wiremixDesktop = mkDesktopFile {
    name = "wiremix";
    displayName = "Wiremix";
    genericName = "Audio Mixer";
    comment = "TUI mixer for PipeWire audio system";
    categories = [ "Audio" "Mixer" "Settings" ];
  };

  clipseDesktop = mkDesktopFile {
    name = "clipse";
    displayName = "Clipse";
    genericName = "Clipboard Manager";
    comment = "TUI clipboard manager with history";
    categories = [ "Utility" ];
  };
in
{
  options.programs.hypr-terminal-apps = {
    enable = lib.mkEnableOption "Hyprland terminal app wrappers";

    bluetui.enable = lib.mkEnableOption "bluetui with alacritty wrapper" // { default = true; };
    wiremix.enable = lib.mkEnableOption "wiremix with alacritty wrapper" // { default = true; };
    clipse.enable = lib.mkEnableOption "clipse with alacritty wrapper" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.flatten [
      (lib.optional cfg.bluetui.enable [ bluetuiWrapper bluetuiDesktop ])
      (lib.optional cfg.wiremix.enable [ wiremixWrapper wiremixDesktop ])
      (lib.optional cfg.clipse.enable [ clipseWrapper clipseDesktop ])
    ];
  };
}

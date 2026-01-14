{
  lib,
  pkgs,
  rustPlatform,
  fetchFromGitHub,
  socat,
  jq,
  makeWrapper,
}:

rustPlatform.buildRustPackage rec {
  pname = "hyprtag";
  version = "unstable-2024-05-15";

  src = fetchFromGitHub {
    owner = "typester";
    repo = "hyprtag";
    rev = "233096930a7f5f0ac4d846e86f8bda27bb205253";
    hash = "sha256-0avcmLQCmmAcmO9xilqY39LD9dLtqy1nusAK8aKoxak=";
  };

  patches = [
    ./fix-socket-path.patch
    ./fix-hyprtagctl-path.patch
    ./add-status-command.patch
  ];

  cargoHash = "sha256-DW0uAsAKtF1nMw9jYLHm6tgxWoWW6PIF/lOGwHbjyYU=";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = let
    waybarScript = pkgs.replaceVars ./hyprtag-status-waybar.sh {
      socat = "${socat}/bin/socat";
      jq = "${jq}/bin/jq";
      hyprtagctl = "$out/bin/hyprtagctl";
    };
  in ''
    # Install hyprtagctl script
    install -Dm755 hyprtagctl $out/bin/hyprtagctl
    wrapProgram $out/bin/hyprtagctl \
      --prefix PATH : ${lib.makeBinPath [ socat ]}

    # Install hyprtag-status-waybar script
    install -Dm755 ${waybarScript} $out/bin/hyprtag-status-waybar
  '';

  meta = with lib; {
    description = "Tag based window management for Hyprland";
    homepage = "https://github.com/typester/hyprtag";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

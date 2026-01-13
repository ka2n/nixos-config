{
  lib,
  rustPlatform,
  fetchFromGitHub,
  socat,
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

  cargoHash = "sha256-scLAkZMRxxTkvvuIqaDrv65SQxVxv9u5QTBkhFj6Z2Y=";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # Install hyprtagctl script
    install -Dm755 hyprtagctl $out/bin/hyprtagctl
    wrapProgram $out/bin/hyprtagctl \
      --prefix PATH : ${lib.makeBinPath [ socat ]}
  '';

  meta = with lib; {
    description = "Tag based window management for Hyprland";
    homepage = "https://github.com/typester/hyprtag";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

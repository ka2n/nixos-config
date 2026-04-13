{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "n";
  version = "0-unstable-2026-04-02";

  src = fetchFromGitHub {
    owner = "ka2n";
    repo = "n";
    rev = "b5d00d2f36316b4e69b583f4c194391da274f0b5";
    hash = "sha256-h6LOUJurbCnFVPz7KngIQyv2L8jWwtryIe8TWyg9wUM=";
  };

  vendorHash = "sha256-UdRyylHSZ/b89cEArilaw6LcAw0epmpH6yCOKOiw9Gw=";

  subPackages = [ "cmd/n" ];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Minimal quick-note-taking CLI with TUI editor";
    homepage = "https://github.com/ka2n/n";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "n";
  };
}

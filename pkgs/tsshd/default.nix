{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "tsshd";
  version = "0.1.6";

  src = fetchFromGitHub {
    owner = "trzsz";
    repo = "tsshd";
    tag = "v${version}";
    hash = "sha256-B5PTiz9luBxkDA9UMSkGYTcPbnXdL43rkFvbOUS5F6w=";
  };

  vendorHash = "sha256-dW05EoAVLqmiPRRG0R4KwKsSijZuxSe15iHkyCImtZY=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "SSH server that works over UDP for unreliable networks";
    homepage = "https://github.com/trzsz/tsshd";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "tsshd";
  };
}

{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "go-readability";
  version = "0-unstable-2025-06-16";

  src = fetchFromGitHub {
    owner = "mackee";
    repo = "go-readability";
    rev = "6ecfbe710834590ddbd51e9aefec27e86358fecc";
    hash = "sha256-/l3KRZOCgZBJSPly06XaYoiLQxtKpH297OUfKRFGor8=";
  };

  vendorHash = "sha256-oaV3QTpc+mREw0vHYiFQDBSY6bL8+MP9qd/o8cGZHmU=";

  subPackages = [ "cmd/readability" ];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Extract main readable content from HTML pages with markdown support";
    homepage = "https://github.com/mackee/go-readability";
    license = licenses.asl20;
    platforms = platforms.unix;
    mainProgram = "readability";
  };
}

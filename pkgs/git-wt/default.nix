{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
  go,
}:

(buildGoModule.override { inherit go; }) rec {
  pname = "git-wt";
  version = "0.29.1";

  src = fetchFromGitHub {
    owner = "k1LoW";
    repo = "git-wt";
    rev = "v${version}";
    hash = "sha256-8WePARXoLC9NV8Z5PSkM2A4UXFxAZOhT6QbSCY+jtaw=";
  };

  vendorHash = "sha256-P8+KiaGZt8j4rRQ4OKP/pQOU8+g2H1snra5dS9Dd8tc=";

  nativeCheckInputs = [ git ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/k1LoW/git-wt/version.Version=${version}"
  ];

  meta = with lib; {
    description = "A Git subcommand that makes git worktree simple";
    homepage = "https://github.com/k1LoW/git-wt";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "git-wt";
  };
}

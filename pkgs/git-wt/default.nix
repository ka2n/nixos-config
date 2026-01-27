{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
}:

buildGoModule rec {
  pname = "git-wt";
  version = "0.16.0";

  src = fetchFromGitHub {
    owner = "k1LoW";
    repo = "git-wt";
    rev = "v${version}";
    hash = "sha256-c2srmNhQWo4z6apNKD0p6gJuy7WwoDGmSjQ3pf0QV6w=";
  };

  vendorHash = "sha256-C8c/AG/TNsIKrnYcK7k/NFajfgZE25xD1QNscyrucfo=";

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

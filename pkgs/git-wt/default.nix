{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
}:

buildGoModule rec {
  pname = "git-wt";
  version = "0.13.1";

  src = fetchFromGitHub {
    owner = "k1LoW";
    repo = "git-wt";
    rev = "v${version}";
    hash = "sha256-uyvLbWsDN2ZxPzkLqHM782L/YyfarOgd8jDfmjtLNRY=";
  };

  vendorHash = "sha256-K5geAvG+mvnKeixOyZt0C1T5ojSBFmx2K/Msol0HsSg=";

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

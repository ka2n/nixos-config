{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
  go,
}:

(buildGoModule.override { inherit go; }) rec {
  pname = "git-wt";
  version = "0.18.1";

  src = fetchFromGitHub {
    owner = "k1LoW";
    repo = "git-wt";
    rev = "v${version}";
    hash = "sha256-1U8oa7AmsIT+T3IqcssGsjQmc+fHKZrg0J9u7ZC32D0=";
  };

  vendorHash = "sha256-0voMoJvahz2WrOepSUPS+3ZC0p1OlEYfgwjrl3EOlU8=";

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

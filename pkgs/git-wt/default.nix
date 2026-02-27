{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
  go,
}:

(buildGoModule.override { inherit go; }) rec {
  pname = "git-wt";
  version = "0.25.0";

  src = fetchFromGitHub {
    owner = "k1LoW";
    repo = "git-wt";
    rev = "v${version}";
    hash = "sha256-QdyONDVokpOaH5dI5v1rmaymCgIiWZ16h26FAIsAHPc=";
  };

  vendorHash = "sha256-O4vqouNxvA3GvrnpRO6GXDD8ysPfFCaaSJVFj2ufxwI=";

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

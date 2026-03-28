pkgs-unstable: llm-agents: final: prev: {
  # claude-code: add gh to PATH (single wrapProgram, no double-wrapping)
  claude-code = llm-agents.claude-code.overrideAttrs (oldAttrs: {
    postFixup = builtins.replaceStrings
      [ "--argv0 claude" ]
      [ "--prefix PATH : ${final.gh}/bin --argv0 claude" ]
      oldAttrs.postFixup;
  });

  libcskk = final.callPackage ./libcskk { };
  fcitx5-cskk = final.callPackage ./fcitx5-cskk {
    inherit (final) libcskk fcitx5;
    inherit (final.qt6) qtbase wrapQtAppsHook;
    inherit (final.kdePackages) fcitx5-qt;
  };
  # octorus: override nixpkgs-unstable version (0.3.5 -> 0.5.4)
  octorus = final.rustPlatform.buildRustPackage {
    pname = "octorus";
    version = "0.5.4";
    src = final.fetchFromGitHub {
      owner = "ushironoko";
      repo = "octorus";
      tag = "v0.5.4";
      hash = "sha256-dsuDn9gNcoI8tKimlxiRdqLGwdQQHZxannc1+zRdtcA=";
    };
    cargoHash = "sha256-K/S4twm7V7cNA6Au30M83E+81dlJsr9l0xfE43fzwDk=";
    nativeBuildInputs = [ final.installShellFiles final.git ];
    preCheck = ''
      export HOME=$(mktemp -d)
      git config --global init.defaultBranch main
      git config --global user.email "test@test.com"
      git config --global user.name "Test"
    '';
    meta = {
      description = "TUI PR review tool for GitHub";
      homepage = "https://github.com/ushironoko/octorus";
      license = final.lib.licenses.mit;
      mainProgram = "octorus";
    };
  };

  # tsshd: build from source (7918c43) for XDG_CONFIG_HOME/tsshd/sshd_config support
  tsshd = final.buildGoModule {
    pname = "tsshd";
    version = "0.1.6-unstable-2026-03-22";
    src = final.fetchFromGitHub {
      owner = "trzsz";
      repo = "tsshd";
      rev = "7918c43b00253873523707c5011a625117c994d6";
      hash = "sha256-6F7nCAHq9vR0L/RnEHNK2TPi5SbYdr8IjZiwBwdghY8=";
    };
    vendorHash = "sha256-c/6jBMrCPYfdWAefN/FQi+gCjejAvNJY/7aI+un6HxE=";
    meta = {
      description = "trzsz SSH daemon over UDP";
      homepage = "https://github.com/trzsz/tsshd";
      license = final.lib.licenses.mit;
      mainProgram = "tsshd";
    };
  };

  keeper-desktop = final.callPackage ./keeper-desktop { };
  display-switch = final.callPackage ./display-switch { };
  alma = final.callPackage ./alma { };
  git-wt = final.callPackage ./git-wt { go = final.go-bin.versions."1.25.7"; };
  go-readability = final.callPackage ./go-readability { };
  mo = final.callPackage ./mo { };
  inputactions-standalone = final.callPackage ./inputactions-standalone { };
  pencil = final.callPackage ./pencil { };
  jai = final.callPackage ./jai { };
}

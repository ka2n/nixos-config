pkgs-unstable: final: prev: {
  # claude-code: add gh to PATH (single wrapProgram, no double-wrapping)
  claude-code = final.llm-agents.claude-code.overrideAttrs (oldAttrs: {
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

  keeper-desktop = final.callPackage ./keeper-desktop { };
  display-switch = final.callPackage ./display-switch { };
  alma = final.callPackage ./alma { };
  git-wt = final.callPackage ./git-wt { go = final.go-bin.versions."1.25.7"; };
  go-readability = final.callPackage ./go-readability { };
  mo = final.callPackage ./mo { };
  inputactions-standalone = final.callPackage ./inputactions-standalone { };
  pencil = final.callPackage ./pencil { };
}

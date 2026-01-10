{ nixpkgs, system }:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
in {
  # 通常利用てんこ盛りパック
  # Usage: nix develop ~/nixos-config
  default = pkgs.mkShell {
    packages = with pkgs; [
      playwright-driver.browsers
      jq
      volta
    ];

    shellHook = ''
      export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
      export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
    '';
  };
}

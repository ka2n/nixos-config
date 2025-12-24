{ config, pkgs, inputs, ... }: {
  home.stateVersion = "25.11";

  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nix-index-database.comma.enable = true;
}

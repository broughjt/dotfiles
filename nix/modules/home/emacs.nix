{
  emacsOverlays,
  configureEmacsPackage,
}:

{ config, pkgs, ... }:

{
  nixpkgs.overlays = emacsOverlays;

  home-manager.users.${config.personal.userName} = {
    programs.emacs = {
      enable = true;
      package = configureEmacsPackage pkgs;
    };
    home.file.".emacs.d" = {
      source = ../../../emacs;
      recursive = true;
      force = true;
    };
    services.emacs = {
      enable = pkgs.stdenv.isLinux;
      package = config.home-manager.users.${config.personal.userName}.programs.emacs.package;
      defaultEditor = true;
    };
  };
}

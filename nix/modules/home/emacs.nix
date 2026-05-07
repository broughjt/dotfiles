{
  emacs-overlay,
  emacsSourceFiles,
  configureEmacsPackage,
}:

{ config, pkgs, ... }:

let
  emacsData = emacsSourceFiles pkgs;
in
{
  nixpkgs.overlays = with emacs-overlay.overlays; [
    emacs
    package
  ];

  home-manager.users.${config.personal.userName} = {
    programs.emacs = {
      enable = true;
      package = configureEmacsPackage pkgs;
    };
    home.file = emacsData.emacsHomeFiles;
    services.emacs = {
      enable = pkgs.stdenv.isLinux;
      package = config.home-manager.users.${config.personal.userName}.programs.emacs.package;
      defaultEditor = true;
    };
  };
}

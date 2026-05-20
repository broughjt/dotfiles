{
  emacsOverlays,
  configureEmacsPackage,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
  emacsStateDirectory = "${localDirectory}/state/emacs";
  emacsCacheDirectory = "${localDirectory}/cache/emacs";

  emacsInitDirectory = ../../../emacs;
  emacsIspellCompleteWordDict = pkgs.runCommand "emacs-ispell-complete-word-dict" { } ''
    ${pkgs.coreutils}/bin/cat \
      ${pkgs.scowl}/lib/aspell/en-common.wl \
      ${pkgs.scowl}/lib/aspell/en_US-wo_accents-only.wl \
      | LC_ALL=C ${pkgs.coreutils}/bin/sort -dfu > "$out"
  '';
  basePackage = configureEmacsPackage pkgs;

  # Keep init.el / early-init.el / modules/ store-backed and pass them to
  # Emacs via --init-directory instead of populating ~/.emacs.d. The wrapper
  # is the package handed to programs.emacs and services.emacs so both
  # interactive `emacs` and `emacs --bg-daemon` use the same init.
  emacsPackage = pkgs.symlinkJoin {
    name = "emacs-with-init-directory";
    paths = [ basePackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/emacs" \
        --add-flags "--init-directory ${emacsInitDirectory}" \
        --set EMACS_ISPELL_COMPLETE_WORD_DICT "${emacsIspellCompleteWordDict}"
    '';
  };
in
{
  nixpkgs.overlays = emacsOverlays;

  # Pre-create the ephemeral state/cache subdirectories Emacs writes to. The
  # parent ~/local/{state,cache} dirs are already declared in linux.nix.
  systemd.tmpfiles.rules = [
    "d ${emacsStateDirectory} 0700 ${user} users -"
    "d ${emacsStateDirectory}/backups 0700 ${user} users -"
    "d ${emacsStateDirectory}/auto-saves 0700 ${user} users -"
    "d ${emacsStateDirectory}/auto-save-list 0700 ${user} users -"
    "d ${emacsStateDirectory}/transient 0700 ${user} users -"
    "d ${emacsCacheDirectory} 0700 ${user} users -"
    "d ${emacsCacheDirectory}/eln-cache 0700 ${user} users -"
  ];

  home-manager.users.${user} = {
    programs.emacs = {
      enable = true;
      package = emacsPackage;
    };
    services.emacs = {
      enable = pkgs.stdenv.isLinux;
      package = emacsPackage;
      defaultEditor = true;
    };
  };
}

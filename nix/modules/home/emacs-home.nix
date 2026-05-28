{ configureEmacsPackage }:

{
  lib,
  pkgs,
  ...
}:

let
  emacsInitDirectory = ../../../emacs;
  emacsIspellCompleteWordDict = pkgs.runCommand "emacs-ispell-complete-word-dict" { } ''
    ${pkgs.coreutils}/bin/cat \
      ${pkgs.scowl}/lib/aspell/en-common.wl \
      ${pkgs.scowl}/lib/aspell/en_US-wo_accents-only.wl \
      | LC_ALL=C ${pkgs.coreutils}/bin/sort -dfu > "$out"
  '';
  basePackage = configureEmacsPackage pkgs;

  # Keep init.el / early-init.el / modules/ store-backed and pass them to
  # Emacs via --init-directory instead of populating ~/.emacs.d. The wrapper is
  # the package handed to programs.emacs and, on Linux, services.emacs so both
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
  config = lib.mkMerge [
    {
      programs.emacs = {
        enable = true;
        package = emacsPackage;
      };
    }

    (lib.mkIf pkgs.stdenv.isLinux {
      services.emacs = {
        enable = true;
        package = emacsPackage;
        defaultEditor = true;
      };
    })
  ];
}

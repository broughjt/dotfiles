{ pi-coding-agent }:

let
  emacsRoot = ../../emacs;
in
rec {
  emacsSourceFiles =
    pkgs:
    let
      emacsFiles = builtins.sort (a: b: (toString a) < (toString b)) (
        pkgs.lib.filesystem.listFilesRecursive emacsRoot
      );
      emacsElFiles = builtins.filter (file: pkgs.lib.strings.hasSuffix ".el" (toString file)) emacsFiles;
      emacsHomeFiles = builtins.listToAttrs (
        map (file: {
          name = ".emacs.d/${pkgs.lib.strings.removePrefix "${toString emacsRoot}/" (toString file)}";
          value = {
            source = file;
          };
        }) emacsFiles
      );
    in
    {
      inherit emacsFiles emacsElFiles emacsHomeFiles;
      emacsConfigText = builtins.concatStringsSep "\n\n" (map builtins.readFile emacsElFiles);
    };

  configureEmacsPackage =
    pkgs:
    let
      emacsSources = emacsSourceFiles pkgs;
    in
    pkgs.emacsWithPackagesFromUsePackage {
      package = pkgs.emacs-git-pgtk;
      config = emacsSources.emacsConfigText;
      defaultInitFile = false;
      override = final: _prev: {
        pi-coding-agent = pi-coding-agent.lib.mkPackage pkgs final;
      };
      extraEmacsPackages =
        epkgs: with epkgs; [
          ghostel
          pi-coding-agent
          treesit-grammars.with-all-grammars
        ];

      alwaysEnsure = true;
    };
}

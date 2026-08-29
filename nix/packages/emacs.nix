{
  configureEmacsPackage =
    pkgs:
    let
      enableTypst = !pkgs.stdenv.hostPlatform.isDarwin;
      emacsBasePackage =
        if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs-git else pkgs.emacs-git-pgtk;
      emacsPackages = pkgs.emacsPackagesFor emacsBasePackage;
      treesitGrammars =
        if enableTypst then
          emacsPackages.treesit-grammars.with-all-grammars
        else
          emacsPackages.treesit-grammars.with-grammars (
            grammars: builtins.attrValues (builtins.removeAttrs grammars [ "tree-sitter-typst" ])
          );
    in
    emacsPackages.emacsWithPackages (
      epkgs:
      [
        # init.el
        epkgs.use-package
        epkgs.bind-key
        epkgs.exec-path-from-shell
        epkgs.envrc
        epkgs.inheritenv

        # completion.el
        epkgs.cape
        epkgs.consult
        epkgs.corfu
        epkgs.jinx
        epkgs.marginalia
        epkgs.orderless
        epkgs.tempel
        epkgs.vertico
        epkgs.which-key

        # editing.el
        epkgs.evil
        epkgs.evil-collection

        # git-config.el
        epkgs.magit

        # language-*.el
        epkgs.apheleia
        epkgs.auctex
        epkgs.grip-mode
        epkgs.haskell-mode
        epkgs.haskell-ts-mode
        epkgs.markdown-mode
        epkgs.nix-mode
        epkgs.racket-mode
        epkgs.rust-mode
        epkgs.verilog-mode

        # ui.el
        epkgs.ef-themes
        epkgs.modus-themes
        epkgs.standard-themes

        # Backs the ts-mode variants above: typescript, tsx, json, haskell,
        # and (on Linux) typst.
        treesitGrammars
      ]
      ++ pkgs.lib.optionals enableTypst [
        epkgs.typst-ts-mode
      ]
    );
}

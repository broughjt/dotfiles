{
  configureEmacsPackage =
    pkgs:
    let
      enableTypst = !pkgs.stdenv.hostPlatform.isDarwin;
      emacsBasePackage = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs31 else pkgs.emacs31-pgtk;
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
        # tree-sitter-haskell 0.24.0 renamed the misspelled `type_synomym` node to
        # `type_synonym`. haskell-ts-mode still queries the old name, which
        # disables its `constructors' font-lock feature (and, on its unreleased
        # HEAD, drops type synonyms from imenu).
        # TODO: Remove this patch once the misspelling is fixed upstream.
        # The package is installed from an ELPA tarball without unpacking, so
        # the patch is applied to the tarball itself.
        (epkgs.haskell-ts-mode.overrideAttrs (old: {
          src = pkgs.runCommand old.src.name { } ''
            tar xf ${old.src}
            substituteInPlace haskell-ts-mode-${old.version}/haskell-ts-mode.el \
              --replace-fail type_synomym type_synonym
            tar cf $out --format=ustar haskell-ts-mode-${old.version}
          '';
        }))
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

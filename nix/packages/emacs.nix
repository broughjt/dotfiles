{ pi-coding-agent }:

{
  configureEmacsPackage =
    pkgs:
    let
      emacsPackages = (pkgs.emacsPackagesFor pkgs.emacs-git-pgtk).overrideScope (
        final: prev: {
          # Emacs 32 rejects nil as a face :background value and warns while
          # loading `standard-dark'.  Standard Themes builds on Modus Themes'
          # `modus-themes-theme' helper, whose fill-column-indicator tty face
          # spec still uses `:background nil'.  Patch the source before byte
          # compilation so the generated Standard face specs are clean at theme
          # load time, rather than correcting the face after the warning fires.
          modus-themes = prev.modus-themes.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace modus-themes.el \
                --replace-fail ':height 1.0 :background nil :foreground ,bg-active' \
                               ':height 1.0 :background unspecified :foreground ,bg-active'
            '';
          });

          pi-coding-agent = pi-coding-agent.lib.mkPackage pkgs final;
        }
      );
    in
    emacsPackages.emacsWithPackages (
      epkgs: with epkgs; [
        # init.el
        use-package
        bind-key
        exec-path-from-shell
        envrc
        inheritenv

        # completion.el
        affe
        cape
        consult
        corfu
        jinx
        marginalia
        orderless
        tempel
        vertico
        which-key

        # editing.el
        evil
        evil-collection
        magit

        # language-*.el
        apheleia
        auctex
        haskell-mode
        markdown-mode
        nix-mode
        racket-mode
        rust-mode
        typst-ts-mode
        verilog-mode

        # pi-coding-agent-config.el
        #
        # Qualified explicitly to bypass `with epkgs`: the function argument
        # `pi-coding-agent` (the flake input) is in the enclosing lexical
        # scope and shadows the `with`-introduced binding, so a bare
        # `pi-coding-agent` here would resolve to the flake source dir
        # rather than the trivialBuild derivation injected by overrideScope.
        epkgs.pi-coding-agent

        # terminal.el
        ghostel

        # ui.el
        ef-themes
        modus-themes
        standard-themes

        # Treesitter grammars needed for pi-coding-agent
        treesit-grammars.with-all-grammars
      ]
    );
}

{ pi-coding-agent }:

{
  configureEmacsPackage =
    pkgs:
    let
      emacsPackages = (pkgs.emacsPackagesFor pkgs.emacs-git-pgtk).overrideScope (
        final: _prev: {
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

        # agent-shell-config.el
        agent-shell

        # completion.el
        affe
        cape
        consult
        corfu
        jinx
        marginalia
        orderless
        vertico
        which-key
        yasnippet

        # editing.el
        evil
        evil-collection
        magit

        # language-*.el
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

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

        # modules/agent-shell-config.el
        agent-shell

        # modules/completion.el
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

        # modules/editing.el
        evil
        evil-collection
        magit

        # modules/languages/*.el
        auctex
        haskell-mode
        markdown-mode
        nix-mode
        racket-mode
        rust-mode
        typst-ts-mode
        verilog-mode

        # modules/pi-coding-agent-config.el
        pi-coding-agent

        # modules/terminal.el
        ghostel

        # modules/ui.el
        ef-themes
        modus-themes
        standard-themes

        # Treesitter grammars needed for pi-pi-coding-agent
        treesit-grammars.with-all-grammars
      ]
    );
}

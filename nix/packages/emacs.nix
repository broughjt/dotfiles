{ pi-coding-agent }:

let
  piCodingAgentInput = pi-coding-agent;
in
{
  configureEmacsPackage =
    pkgs:
    let
      enableTypst = !pkgs.stdenv.isDarwin;
      emacsBasePackage = if pkgs.stdenv.isDarwin then pkgs.emacs-git else pkgs.emacs-git-pgtk;
      emacsPackages = (pkgs.emacsPackagesFor emacsBasePackage).overrideScope (
        final: prev: {
          pi-coding-agent = pi-coding-agent.lib.mkPackage pkgs final;
        }
      );
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
        epkgs.affe
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
        epkgs.magit

        # language-*.el
        epkgs.apheleia
        epkgs.auctex
        epkgs.grip-mode
        epkgs.haskell-mode
        epkgs.markdown-mode
        epkgs.nix-mode
        epkgs.racket-mode
        epkgs.rust-mode
        epkgs.verilog-mode

        # pi-coding-agent-config.el
        #
        # Qualified explicitly to bypass `with epkgs`: the function argument
        # `pi-coding-agent` (the flake input) is in the enclosing lexical
        # scope and shadows the `with`-introduced binding, so a bare
        # `pi-coding-agent` here would resolve to the flake source dir
        # rather than the trivialBuild derivation injected by overrideScope.
        epkgs.pi-coding-agent

        # ui.el
        epkgs.ef-themes
        epkgs.modus-themes
        epkgs.standard-themes

        # Treesitter grammars needed for pi-coding-agent
        treesitGrammars
      ]
      ++ pkgs.lib.optionals enableTypst [
        epkgs.typst-ts-mode
      ]
    );
}

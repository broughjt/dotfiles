{ pi-coding-agent }:

let
  piCodingAgentInput = pi-coding-agent;
in
{
  configureEmacsPackage =
    pkgs:
    let
      emacsPackages = (pkgs.emacsPackagesFor pkgs.emacs-git-pgtk).overrideScope (
        final: _prev: {
          pi-coding-agent = piCodingAgentInput.lib.mkPackage pkgs final;
        }
      );
    in
    emacsPackages.emacsWithPackages (epkgs: [
      # init.el
      epkgs.use-package
      epkgs.bind-key
      epkgs.exec-path-from-shell
      epkgs.envrc
      epkgs.inheritenv

      # modules/agent-shell-config.el
      epkgs.agent-shell

      # modules/completion.el
      epkgs.affe
      epkgs.cape
      epkgs.consult
      epkgs.corfu
      epkgs.jinx
      epkgs.marginalia
      epkgs.orderless
      epkgs.vertico
      epkgs.which-key
      epkgs.yasnippet

      # modules/editing.el
      epkgs.evil
      epkgs.evil-collection
      epkgs.magit

      # modules/languages/*.el
      epkgs.auctex
      epkgs.haskell-mode
      epkgs.markdown-mode
      epkgs.nix-mode
      epkgs.racket-mode
      epkgs.rust-mode
      epkgs.typst-ts-mode
      epkgs.verilog-mode

      # modules/pi-coding-agent-config.el
      epkgs.pi-coding-agent

      # modules/terminal.el
      epkgs.ghostel

      # modules/ui.el
      epkgs.ef-themes
      epkgs.modus-themes
      epkgs.standard-themes

      # Treesitter grammars needed for pi-pi-coding-agent
      epkgs.treesit-grammars.with-all-grammars
    ]);
}

{ pi-coding-agent }:

let
  piCodingAgentInput = pi-coding-agent;
in
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
    emacsPackages.emacsWithPackages (epkgs: [
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
      epkgs.haskell-mode
      epkgs.markdown-mode
      epkgs.nix-mode
      epkgs.racket-mode
      epkgs.rust-mode
      epkgs.typst-ts-mode
      epkgs.verilog-mode

      # pi-coding-agent-config.el
      #
      # Qualified explicitly to bypass `with epkgs`: the function argument
      # `pi-coding-agent` (the flake input) is in the enclosing lexical
      # scope and shadows the `with`-introduced binding, so a bare
      # `pi-coding-agent` here would resolve to the flake source dir
      # rather than the trivialBuild derivation injected by overrideScope.
      epkgs.pi-coding-agent

      # terminal.el
      epkgs.ghostel

      # ui.el
      epkgs.ef-themes
      epkgs.modus-themes
      epkgs.standard-themes

      # Treesitter grammars needed for pi-coding-agent
      epkgs.treesit-grammars.with-all-grammars
    ]);
}

{
  nixpkgs,
  flake-utils,
  llm-agents-nix,
  emacs-overlay,
  configureEmacsPackage,
}:

flake-utils.lib.eachDefaultSystem (
  system:
  let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        llm-agents-nix.overlays.default
      ]
      ++ (with emacs-overlay.overlays; [
        emacs
        package
      ]);
      config.allowUnfree = true;
    };
    emacsPackage = configureEmacsPackage pkgs;
  in
  {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        nil
        nixfmt
      ];
    };
    checks.emacs-byte-compile = pkgs.runCommand "emacs-byte-compile-check" { src = ../.; } ''
      cp -r "$src/emacs" .
      chmod -R u+w emacs
      HOME="$TMPDIR" ${emacsPackage}/bin/emacs --batch \
        -L emacs -L emacs/modules -L emacs/modules/languages \
        --eval "(setq byte-compile-error-on-warn t)" \
        -f batch-byte-compile \
        emacs/init.el emacs/modules/*.el emacs/modules/languages/*.el
      mkdir -p "$out"
    '';
  }
)

{
  pkgs,
  emacsPackage,
}:

{
  checks = {
    actionlint = pkgs.runCommand "github-actions-actionlint-check" { src = ../.; } ''
      cd "$src"
      ${pkgs.actionlint}/bin/actionlint .github/workflows/*.yml
      mkdir -p "$out"
    '';

    emacs-byte-compile = pkgs.runCommand "emacs-byte-compile-check" { src = ../.; } ''
      cp -r "$src/emacs" .
      chmod -R u+w emacs
      mkdir -p "$TMPDIR/state" "$TMPDIR/cache"
      HOME="$TMPDIR" \
      XDG_STATE_HOME="$TMPDIR/state" \
      XDG_CACHE_HOME="$TMPDIR/cache" \
        ${emacsPackage}/bin/emacs --batch \
        -L emacs/lisp \
        --eval "(setq byte-compile-error-on-warn t)" \
        -f batch-byte-compile \
        emacs/init.el emacs/lisp/*.el
      mkdir -p "$out"
    '';
  };
}

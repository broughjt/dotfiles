{
  pkgs,
  emacsPackage,
}:

{
  checks.emacs-byte-compile = pkgs.runCommand "emacs-byte-compile-check" { src = ../.; } ''
    cp -r "$src/emacs" .
    chmod -R u+w emacs
    HOME="$TMPDIR" ${emacsPackage}/bin/emacs --batch \
      -L emacs/lisp \
      --eval "(setq byte-compile-error-on-warn t)" \
      -f batch-byte-compile \
      emacs/init.el emacs/lisp/*.el
    mkdir -p "$out"
  '';
}

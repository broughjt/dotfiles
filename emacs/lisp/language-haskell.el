;;; -*- lexical-binding: t; -*-

(defun jackson/haskell-project-has-formatter-config-p ()
  (or (locate-dominating-file default-directory "fourmolu.yaml")
      (locate-dominating-file default-directory "ormolu.yaml")
      (locate-dominating-file default-directory ".stylish-haskell.yaml")))

(defun jackson/enable-haskell-apheleia-if-configured ()
  (when (jackson/haskell-project-has-formatter-config-p)
    (apheleia-mode 1)))

(use-package apheleia
  :hook ((haskell-mode . jackson/enable-haskell-apheleia-if-configured)
         (haskell-ts-mode . jackson/enable-haskell-apheleia-if-configured)))

(use-package haskell-mode
  :mode "\\.hs\\'"
  :init
  ;; `haskell-mode' installs hooks/CAPFs pointing at helper functions in
  ;; sibling files.  Normally package activation loads these autoloads, but we
  ;; manage packages with Nix and disable package.el startup activation.
  (require 'haskell-mode-autoloads)
  :hook
  ((haskell-mode . eglot-ensure)))

(provide 'language-haskell)

;;; -*- lexical-binding: t; -*-

(use-package apheleia
  :hook ((haskell-mode . apheleia-mode)
         (haskell-ts-mode . apheleia-mode)))

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

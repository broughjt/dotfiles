;;; -*- lexical-binding: t; -*-

(use-package apheleia
  :hook ((haskell-mode . apheleia-mode)
         (haskell-ts-mode . apheleia-mode)))

(use-package haskell-mode
  :mode "\\.hs\\'"
  :hook
  ((haskell-mode . eglot-ensure)))

(provide 'language-haskell)

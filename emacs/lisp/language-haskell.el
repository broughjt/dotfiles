;;; -*- lexical-binding: t; -*-

(use-package haskell-mode
  :mode "\\.hs\\'"
  :hook
  ((haskell-mode . eglot-ensure)))

(provide 'language-haskell)

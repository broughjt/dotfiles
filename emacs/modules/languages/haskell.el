;;; -*- lexical-binding: t; -*-

(use-package haskell-mode
  :hook
  ((haskell-mode . eglot-ensure)))

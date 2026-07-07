;;; -*- lexical-binding: t; -*-

(use-package eglot
  :bind (:map eglot-mode-map
              ("C-c e a" . eglot-code-actions)))

(provide 'language-eglot)

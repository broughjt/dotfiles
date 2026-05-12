;;; -*- lexical-binding: t; -*-

(defvar eglot-server-programs)
(declare-function eglot-alternatives "eglot" (servers))

(use-package typst-ts-mode
  :mode "\\.typ\\'"
  :hook
  ((typst-ts-mode . eglot-ensure))
  :custom
  (typst-ts-indent-offset 2)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 `((typst-ts-mode) . ,(eglot-alternatives `("tinymist"))))))

(provide 'language-typst)

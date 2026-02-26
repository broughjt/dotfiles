(use-package typst-ts-mode
  :hook
  ((typst-ts-mode . eglot-ensure))
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 `((typst-ts-mode) . ,(eglot-alternatives `("tinymist"))))))

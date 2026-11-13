;;; -*- lexical-binding: t; -*-

(defvar eglot-server-programs)
(declare-function eglot-alternatives "eglot" (servers))

(use-package typst-ts-mode
  :mode "\\.typ\\'"
  ;; TODO: Disable tinymist for now
  ;; :hook
  ;; (typst-ts-mode . eglot-ensure)
  :custom
  (typst-ts-indent-offset 2)
  ;; TODO: Disable tinymist for now
  ;; :config
  ;; (with-eval-after-load 'eglot
  ;;   (add-to-list 'eglot-server-programs
  ;;                `((typst-ts-mode) . ,(eglot-alternatives `("tinymist")))))
  )

(provide 'language-typst)

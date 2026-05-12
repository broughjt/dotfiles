;;; -*- lexical-binding: t; -*-

(defvar eglot-server-programs)

(use-package apheleia
  :hook ((rust-mode . apheleia-mode)
         (rust-ts-mode . apheleia-mode)))

(use-package rust-mode
  :mode "\\.rs\\'"
  :hook (rust-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((rust-ts-mode rust-mode) .
                   ("rust-analyzer"
                    :initializationOptions
                    (:check (:command "clippy")))))))

(provide 'language-rust)

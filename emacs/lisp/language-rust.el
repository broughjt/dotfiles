;;; -*- lexical-binding: t; -*-

(defvar eglot-server-programs)
(defvar rust-mode-treesitter-derive)

(use-package apheleia
  :hook (rust-mode . apheleia-mode))

(use-package rust-mode
  ;; TODO: slow?
  ;; :init
  ;; (setq rust-mode-treesitter-derive t)
  :mode "\\.rs\\'"
  :hook (rust-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((rust-mode) .
                   ("rust-analyzer"
                    :initializationOptions
                    (:check (:command "clippy")))))))

(provide 'language-rust)

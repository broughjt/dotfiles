;; (use-package rustic
;;   :hook
;;   ((rustic-mode . eglot-ensure))
;;   :config
;;   (setq rustic-lsp-client 'eglot)
;;   (setq-default eglot-workspace-configuration
;;                 '(:rust-analyzer (:check (:command "clippy")))))

(use-package rust-mode
  :init
  (setq rust-mode-treesitter-derive t)
  :hook (rust-mode . eglot-ensure)
  :config 
  ;; (add-to-list
  ;;  'eglot-server-programs
  ;;  '((rust-ts-mode rust-mode) .
  ;;    ("rust-analyzer" :initializationOptions (:check (:command "clippy"))))))

  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((rust-ts-mode rust-mode) .
                   ("rust-analyzer"
                    :initializationOptions
                    (:check (:command "clippy")))))))
  

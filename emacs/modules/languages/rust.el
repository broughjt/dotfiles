(use-package rustic
  :hook
  ((rustic-mode . eglot-ensure))
  :config
  (setq rustic-lsp-client 'eglot)
  (setq-default eglot-workspace-configuration
                '(:rust-analyzer (:check (:command "clippy")))))

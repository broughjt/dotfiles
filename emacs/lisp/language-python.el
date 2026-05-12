;;; -*- lexical-binding: t; -*-

(defvar eglot-server-programs)

(use-package python
  :ensure nil
  :mode ("\\.py\\'" . python-ts-mode)
  :hook ((python-mode . eglot-ensure)
         (python-ts-mode . eglot-ensure))
  :config
  (with-eval-after-load 'eglot
    ;; Prefer the project's Nix-provided static type checker. Eglot's built-in
    ;; Python server list also includes Ruff; keeping this explicit avoids an
    ;; interactive server-selection prompt when both tools are in the dev shell.
    (add-to-list 'eglot-server-programs
                 '((python-mode python-ts-mode)
                   . ("basedpyright-langserver" "--stdio")))))

(provide 'language-python)

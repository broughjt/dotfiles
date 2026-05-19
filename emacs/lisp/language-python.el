;;; -*- lexical-binding: t; -*-

(defvar apheleia-mode-alist)
(defvar eglot-server-programs)

(use-package apheleia
  :hook ((python-mode . apheleia-mode)
         (python-ts-mode . apheleia-mode))
  :config
  ;; Use Ruff from the project environment for Python formatting and import
  ;; sorting. Apheleia runs formatters from PATH and skips missing executables,
  ;; so projects without Ruff in their environment are left alone.
  (setf (alist-get 'python-mode apheleia-mode-alist) '(ruff-isort ruff))
  (setf (alist-get 'python-ts-mode apheleia-mode-alist) '(ruff-isort ruff)))

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

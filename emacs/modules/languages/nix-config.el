;;; -*- lexical-binding: t; -*-

(defvar eglot-server-programs)

(declare-function eglot-format-buffer "eglot")

(defun jackson/nix-format-on-save ()
  (add-hook 'before-save-hook #'eglot-format-buffer nil t))

(use-package nix-mode
  :mode "\\.nix\\'"
  :hook ((nix-mode . eglot-ensure)
         (nix-mode . jackson/nix-format-on-save))
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(nix-mode .
                   ("nil"
                    :initializationOptions
                    (:nil (:formatting (:command ["nixfmt"]))))))))

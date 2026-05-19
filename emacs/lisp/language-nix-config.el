;;; -*- lexical-binding: t; -*-

(defvar eglot-server-programs)

(use-package apheleia
  :hook ((nix-mode . apheleia-mode)
         (nix-ts-mode . apheleia-mode)))

(use-package nix-mode
  :mode "\\.nix\\'"
  :hook (nix-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(nix-mode .
                   ("nil"
                    :initializationOptions
                    (:nil (:formatting (:command ["nixfmt"]))))))))

(provide 'language-nix-config)

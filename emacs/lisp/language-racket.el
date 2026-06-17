;;; -*- lexical-binding: t; -*-

(defvar jackson/emacs-cache-directory)
(defvar jackson/emacs-hacks-directory)
(defvar racket-doc-index-directory)
(defvar racket-hash-lang-module-language-hook)
(defvar racket-repl-buffer-name-function)
(defvar racket-repl-command-file)
(defvar racket-repl-history-directory)
(defvar racket-xp-add-binding-faces)

(declare-function racket-hash-lang-mode "racket-hash-lang")
(declare-function racket-mode "racket-mode")
(declare-function racket-repl-buffer-name-project "racket-repl-buffer-name")
(declare-function racket-xp-mode "racket-xp" (&optional arg))

(defun jackson/racket-hash-lang-module-language-setup (_module-language)
  "Personal defaults applied whenever a `racket-hash-lang-mode' #lang changes."
  ;; `racket-hash-lang-mode' intentionally uses plain DrRacket-style token
  ;; colors from the language. Let `racket-xp-mode' add check-syntax-style
  ;; binding/use faces on top of those token colors.
  (setq-local racket-xp-add-binding-faces t))

(use-package racket-mode
  :commands racket-mode
  :mode (("\\.rktd\\'" . racket-mode)
         ("\\.rktl\\'" . racket-mode))
  :hook (racket-mode . racket-xp-mode)
  :custom
  ;; `user-emacs-directory' is the read-only Nix store init directory. Keep
  ;; racket-mode's mutable files under the configured XDG/local trees instead.
  (racket-doc-index-directory
   (file-name-as-directory
    (expand-file-name "racket-mode" jackson/emacs-cache-directory)))
  (racket-repl-command-file
   (expand-file-name "repl.rkt"
                     (file-name-as-directory
                      (expand-file-name "racket-mode" jackson/emacs-hacks-directory))))
  (racket-repl-history-directory
   (file-name-as-directory
    (expand-file-name "racket-mode" jackson/emacs-hacks-directory)))
  ;; Share one REPL per project instead of creating/using one global REPL.
  (racket-repl-buffer-name-function #'racket-repl-buffer-name-project)
  ;; Also enrich classic `racket-mode' buffers with check-syntax faces.
  (racket-xp-add-binding-faces t))

(use-package racket-xp
  :commands racket-xp-mode)

(use-package racket-hash-lang
  :commands racket-hash-lang-mode
  :mode (("\\.rkt\\'" . racket-hash-lang-mode)
         ("\\.scrbl\\'" . racket-hash-lang-mode)
         ("\\.rhm\\'" . racket-hash-lang-mode))
  :hook (racket-hash-lang-mode . racket-xp-mode)
  :config
  (add-hook 'racket-hash-lang-module-language-hook
            #'jackson/racket-hash-lang-module-language-setup))

(provide 'language-racket)

;;; -*- lexical-binding: t; -*-

(defvar racket-xp-add-binding-faces)
(defvar racket-repl-buffer-name-function)
(defvar racket-hash-lang-module-language-hook)

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

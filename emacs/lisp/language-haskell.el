;;; -*- lexical-binding: t; -*-

(declare-function apheleia-mode "apheleia" (&optional arg))

(defun jackson/haskell-project-has-formatter-config-p ()
  (or (locate-dominating-file default-directory "fourmolu.yaml")
      (locate-dominating-file default-directory "ormolu.yaml")
      (locate-dominating-file default-directory ".stylish-haskell.yaml")))

(defun jackson/enable-haskell-apheleia-if-configured ()
  (when (jackson/haskell-project-has-formatter-config-p)
    (apheleia-mode 1)))

(use-package apheleia
  :hook ((haskell-mode . jackson/enable-haskell-apheleia-if-configured)
         (haskell-ts-mode . jackson/enable-haskell-apheleia-if-configured)))

;; Prefer the tree-sitter major mode for Haskell. Stock `haskell-mode' uses a
;; regexp `syntax-propertize-function' to disambiguate apostrophes (identifier
;; primes like `foldl'' from char literals like `?a') and to track backslash
;; string gaps. On a buffer dense with both, that propertizer goes superlinear
;; and is re-run from redisplay, freezing the buffer until `C-g'. `haskell-ts-mode'
;; parses incrementally in C and installs no propertizer, so the freeze cannot
;; occur; eglot still supplies every semantic feature.
(use-package haskell-ts-mode
  :mode "\\.hs\\'"
  :init
  ;; Route anything that would otherwise enter `haskell-mode' (file-local
  ;; `mode:' cookies, other packages) through the tree-sitter mode as well.
  (add-to-list 'major-mode-remap-alist '(haskell-mode . haskell-ts-mode))
  :hook (haskell-ts-mode . eglot-ensure))

;; Keep stock `haskell-mode' installed as a fallback (`M-x haskell-mode' bypasses
;; the remap above). Its interactive features live in sibling files wired up by
;; autoloads, which we must load explicitly because package.el startup
;; activation is disabled under Nix.
(use-package haskell-mode
  :defer t
  :init
  (require 'haskell-mode-autoloads))

(provide 'language-haskell)

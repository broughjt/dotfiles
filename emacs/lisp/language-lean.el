;;; -*- lexical-binding: t; -*-

(defvar jackson/emacs-state-directory)
(defvar jackson/emacs-cache-directory)
(defvar lsp-keymap-prefix)
(defvar lsp-lens-enable)
(defvar lsp-server-install-dir)
(defvar lsp-session-file)

(declare-function lsp-deferred "lsp-mode")

(use-package lsp-mode
  :commands (lsp lsp-deferred)
  :init
  (setq lsp-keymap-prefix "C-c l"
        lsp-lens-enable nil
        lsp-enable-snippet nil ;; TODO: Get it to work with tempel maybe?
        lsp-session-file (expand-file-name "lsp-session-v1" jackson/emacs-state-directory)
        lsp-server-install-dir (expand-file-name "lsp/" jackson/emacs-cache-directory))
  (require 'lsp-headerline)
  (require 'lsp-modeline))

(use-package lean4-mode
  :mode "\\.lean\\'"
  :hook (lean4-mode . lsp-deferred))

(provide 'language-lean)

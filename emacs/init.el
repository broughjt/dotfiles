;;; -*- lexical-binding: t; -*-

(require 'package)

(defvar use-package-ensure-function)
(defvar local-directory)
(defvar backup-directory)
(defvar auto-save-directory)

(declare-function exec-path-from-shell-initialize "exec-path-from-shell")
(declare-function envrc-global-mode "envrc" (&optional arg))

(setq package-enable-at-startup nil)
(setq use-package-ensure-function 'ignore)
(setq package-archives nil)

(require 'bind-key)
(require 'seq)

(defvar emacs-config-directory
  (file-name-directory (or load-file-name user-init-file))
  "Absolute path to this Emacs configuration directory.")

(setq local-directory (expand-file-name "~/.local/data/emacs/"))
(setq custom-file (concat local-directory "custom.el"))
(load custom-file)

(setq backup-directory (concat local-directory "backups/"))
(setq auto-save-directory (concat local-directory "auto-saves/"))

(setq backup-directory-alist `((".*" . ,backup-directory)))
(setq auto-save-file-name-transforms `((".*" ,auto-save-directory t)))

(setq create-lockfiles nil)

(unless (eq system-type 'windows-nt)
  (use-package exec-path-from-shell
    :config
    (dolist (var '("SSH_AUTH_SOCK"
                   "SSH_AGENT_PID"
                   "GPG_AGENT_INFO"
                   "GNUPGHOME"
                   "LANG"
                   "LC_CTYPE"
                   "NIX_SSL_CERT_FILE"
                   "NIX_PATH"))
      (add-to-list 'exec-path-from-shell-variables var))
    (exec-path-from-shell-initialize)))

(use-package envrc
  :config
  (envrc-global-mode))

(use-package inheritenv
  :demand t)

(load (expand-file-name "modules/ui.el" emacs-config-directory))
(load (expand-file-name "modules/editing.el" emacs-config-directory))
(load (expand-file-name "modules/completion.el" emacs-config-directory))
(load (expand-file-name "modules/agent-shell-config.el" emacs-config-directory))
(load (expand-file-name "modules/languages/tex.el" emacs-config-directory))
(load (expand-file-name "modules/languages/racket.el" emacs-config-directory))
(load (expand-file-name "modules/languages/rust.el" emacs-config-directory))
(load (expand-file-name "modules/languages/lean.el" emacs-config-directory))
(load (expand-file-name "modules/languages/haskell.el" emacs-config-directory))
(load (expand-file-name "modules/languages/nix-config.el" emacs-config-directory))
(load (expand-file-name "modules/languages/agda.el" emacs-config-directory))
(load (expand-file-name "modules/languages/javascript.el" emacs-config-directory))
(load (expand-file-name "modules/languages/typst.el" emacs-config-directory))
(load (expand-file-name "modules/languages/verilog.el" emacs-config-directory))
(load (expand-file-name "modules/languages/markdown.el" emacs-config-directory))
(load (expand-file-name "modules/phelps.el" emacs-config-directory))

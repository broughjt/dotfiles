;;; -*- lexical-binding: t; -*-

(require 'package)

(defvar use-package-ensure-function)

(declare-function exec-path-from-shell-initialize "exec-path-from-shell")
(declare-function envrc-global-mode "envrc" (&optional arg))

(setq use-package-ensure-function 'ignore)
(setq package-archives nil)

(require 'use-package)
(require 'bind-key)
(require 'seq)

(defvar emacs-config-directory
  (file-name-directory (or load-file-name user-init-file))
  "Absolute path to this Emacs configuration directory.")

;; State paths. The directory defvars (`jackson/emacs-state-directory',
;; `jackson/emacs-cache-directory', `jackson/emacs-hacks-directory') and the
;; eln-cache redirect are set in early-init.el; everything else lives here.

;; Backups. Rename target on first save of a buffer in a session, kept after
;; subsequent saves. Persisted across reboots so unintended overwrites in
;; non-VC files (notes, scratch, configs outside git) remain recoverable.
(setq backup-directory-alist
      `((".*" . ,(expand-file-name "backups/" jackson/emacs-state-directory))))

;; Auto-saves. Periodic working-copy snapshots, deleted on successful explicit
;; save. Persisted across reboots so `M-x recover-file' works after a crash
;; that takes down the whole machine, not just Emacs.
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-saves/" jackson/emacs-state-directory) t)))

;; Per-session auto-save index used by `M-x recover-session'. Disposable
;; across reboots; only useful within the lifetime of a single Emacs process.
(setq auto-save-list-file-prefix
      (expand-file-name "auto-save-list/.saves-" jackson/emacs-state-directory))

;; File locks (.#name) are unnecessary on a single-user workstation and
;; clutter project trees.
(setq create-lockfiles nil)

;; Transient (magit/etc) UI history. Ephemeral; rebuilds with use.
(setq transient-history-file
      (expand-file-name "transient/history.el" jackson/emacs-state-directory))
(setq transient-values-file
      (expand-file-name "transient/values.el" jackson/emacs-state-directory))
(setq transient-levels-file
      (expand-file-name "transient/levels.el" jackson/emacs-state-directory))

;; Known projects, narrowly persisted via ~/local/hacks/emacs/projects so
;; `project-switch-project' remembers visited roots across reboots.
(setq project-list-file
      (expand-file-name "projects/projects.eld" jackson/emacs-hacks-directory))

;; Bookmarks are not currently used, but `M-x bookmark-set' would otherwise
;; try to write inside the read-only user-emacs-directory. Redirect to
;; ephemeral state so accidental use is harmless.
(setq bookmark-default-file
      (expand-file-name "bookmarks" jackson/emacs-state-directory))

;; Customize storage. Declarative config is the source of truth, so route any
;; accidental `M-x customize-save-variable' writes into ephemeral state.
(setq custom-file
      (expand-file-name "custom.el" jackson/emacs-state-directory))

(unless (eq system-type 'windows-nt)
  (use-package exec-path-from-shell
    :config
    (dolist (var '("SSH_AUTH_SOCK"
                   "SSH_AGENT_PID"
                   "GPG_AGENT_INFO"
                   "GNUPGHOME"
                   "GIT_CONFIG_GLOBAL"
                   "XDG_CONFIG_HOME"
                   "XDG_CACHE_HOME"
                   "XDG_DATA_HOME"
                   "XDG_STATE_HOME"
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
(load (expand-file-name "modules/pi-coding-agent-config.el" emacs-config-directory))
(load (expand-file-name "modules/terminal.el" emacs-config-directory))
(load (expand-file-name "modules/project-config.el" emacs-config-directory))
(load (expand-file-name "modules/languages/tex.el" emacs-config-directory))
(load (expand-file-name "modules/languages/racket.el" emacs-config-directory))
(load (expand-file-name "modules/languages/rust.el" emacs-config-directory))
(load (expand-file-name "modules/languages/haskell.el" emacs-config-directory))
(load (expand-file-name "modules/languages/nix-config.el" emacs-config-directory))
(load (expand-file-name "modules/languages/agda.el" emacs-config-directory))
(load (expand-file-name "modules/languages/javascript.el" emacs-config-directory))
(load (expand-file-name "modules/languages/typst.el" emacs-config-directory))
(load (expand-file-name "modules/languages/verilog.el" emacs-config-directory))
(load (expand-file-name "modules/languages/markdown.el" emacs-config-directory))
(load (expand-file-name "modules/phelps.el" emacs-config-directory))

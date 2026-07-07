;;; -*- lexical-binding: t; -*-

(require 'package)

(defvar use-package-ensure-function)

;; Defined in early-init.el. Forward-declared so byte-compile knows the
;; references below are bound (the byte-compile check loads init.el and modules
;; directly).
(defvar jackson/emacs-state-directory)
(defvar jackson/emacs-cache-directory)
(defvar jackson/emacs-hacks-directory)

;; Forward declarations for variables defined by their respective packages
;; (or by built-in libraries that are autoloaded only on first use). The
;; setq's below run at init time, before those packages/libraries are loaded.
(defvar transient-history-file)
(defvar transient-values-file)
(defvar transient-levels-file)
(defvar project-list-file)
(defvar bookmark-default-file)

(declare-function exec-path-from-shell-initialize "exec-path-from-shell")
(declare-function envrc-global-mode "envrc" (&optional arg))

(setq use-package-ensure-function 'ignore)
(setq package-archives nil)

(require 'use-package)
(require 'bind-key)
(require 'seq)

(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name user-init-file))))

;;; Nix-managed state configuration

(when (eq system-type 'darwin)
  ;; murph creates these through systemd tmpfiles so missing directories remain
  ;; visible as Linux configuration bugs. On macOS, Home Manager may not have
  ;; created anything before a GUI launch, so create the normal state/cache
  ;; directories lazily.
  (dolist (directory (list jackson/emacs-state-directory
                           (expand-file-name "backups/" jackson/emacs-state-directory)
                           (expand-file-name "auto-saves/" jackson/emacs-state-directory)
                           (expand-file-name "auto-save-list/" jackson/emacs-state-directory)
                           (expand-file-name "transient/" jackson/emacs-state-directory)
                           jackson/emacs-cache-directory
                           (expand-file-name "eln-cache/" jackson/emacs-cache-directory)
                           (expand-file-name "lsp/" jackson/emacs-cache-directory)
                           jackson/emacs-hacks-directory
                           (expand-file-name "projects/" jackson/emacs-hacks-directory)))
    (make-directory directory t)))

;; Backups: Rename target on first save of a buffer in a session, kept after
;; subsequent saves. Persisted across reboots so unintended overwrites in files
;; outside of version control remain recoverable.
(setq backup-directory-alist
      `((".*" . ,(expand-file-name "backups/" jackson/emacs-state-directory))))

;; Auto-saves: Periodic working-copy snapshots, deleted on successful explicit
;; save. Persisted across reboots so `M-x recover-file' works after a crash
;; that takes down the whole machine, not just Emacs.
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-saves/" jackson/emacs-state-directory) t)))

;; Per-session auto-save index used by `M-x recover-session': disposable
;; across reboots. Only useful within the lifetime of a single Emacs process.
(setq auto-save-list-file-prefix
      (expand-file-name "auto-save-list/.saves-" jackson/emacs-state-directory))

;; Don't create those annoying file locks (.#name). Nobody else is running Emacs
;; on my machine, who am I worried about clobbering me?
(setq create-lockfiles nil)

;; Transient (magit/etc) UI history.
(setq transient-history-file
      (expand-file-name "transient/history.el" jackson/emacs-state-directory))
(setq transient-values-file
      (expand-file-name "transient/values.el" jackson/emacs-state-directory))
(setq transient-levels-file
      (expand-file-name "transient/levels.el" jackson/emacs-state-directory))

;; List of known projects. Narrowly persisted in ~/local/hacks/emacs/projects so
;; `project-switch-project' remembers visited project roots across reboots.
(setq project-list-file
      (expand-file-name "projects/projects.eld" jackson/emacs-hacks-directory))

;; Bookmarks are not currently used, but `M-x bookmark-set' would otherwise
;; try to write inside the read-only user-emacs-directory. Redirect to
;; ephemeral state so accidental use is harmless.
;; TODO: Try bookmarks
(setq bookmark-default-file
      (expand-file-name "bookmarks" jackson/emacs-state-directory))

;; Customize storage. Route anything set with this to ephemeral state.
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

;;; Load the goods

(mapc #'require
      '(ui
        editing
        completion
        pi-coding-agent-config
        project-config
        language-eglot
        language-tex
        language-racket
        language-rust
        language-c-cpp
        language-haskell
        language-nix-config
        language-python
        language-agda
        language-javascript
        language-verilog
        language-markdown
        language-lean
        weibian))

;; typst-ts-mode is intentionally omitted from the Darwin package set because
;; the work Mac has trouble fetching/building the NonGNU ELPA source during Nix
;; builds. Load the Typst config only on systems where the package is present.
(when (locate-library "typst-ts-mode")
  (require 'language-typst))

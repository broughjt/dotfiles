;;; -*- lexical-binding: t; -*-

;; Disable package.el's automatic package activation. Packages are supplied by
;; Nix and configured explicitly from init.el with use-package.
(setq package-enable-at-startup nil)

;; typst-ts-mode 0.12.2's generated autoloads contain a top-level
;; `define-compilation-mode' form. If anything activates package autoloads
;; before compile.el is loaded, startup reports:
;;   Error loading autoloads: (void-function define-compilation-mode)
(require 'compile)

;; This Emacs is started with `--init-directory <store-path>', so
;; `user-emacs-directory' is a read-only /nix/store path. Redirect every
;; subsystem that wants to write next to init.el at runtime.

(defvar jackson/emacs-state-directory
  (file-name-as-directory
   (expand-file-name "emacs"
                     (or (getenv "XDG_STATE_HOME")
                         (expand-file-name "~/local/state"))))
  "Ephemeral Emacs state under $XDG_STATE_HOME/emacs.")

(defvar jackson/emacs-cache-directory
  (file-name-as-directory
   (expand-file-name "emacs"
                     (or (getenv "XDG_CACHE_HOME")
                         (expand-file-name "~/local/cache"))))
  "Ephemeral Emacs cache under $XDG_CACHE_HOME/emacs.")

(defvar jackson/emacs-hacks-directory
  (file-name-as-directory
   (expand-file-name "hacks/emacs" (expand-file-name "~/local")))
  "Narrowly persisted Emacs state under ~/local/hacks/emacs.")

;; Native compilation cache. Must be redirected before native-comp loads.
(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (expand-file-name "eln-cache/" jackson/emacs-cache-directory)))

;; Backups, auto-saves, and auto-save-list.
(setq backup-directory-alist
      `((".*" . ,(expand-file-name "backups/" jackson/emacs-state-directory))))
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-saves/" jackson/emacs-state-directory) t)))
(setq auto-save-list-file-prefix
      (expand-file-name "auto-save-list/.saves-" jackson/emacs-state-directory))
(setq create-lockfiles nil)

;; Magit/transient history. Ephemeral.
(setq transient-history-file
      (expand-file-name "transient/history.el" jackson/emacs-state-directory))
(setq transient-values-file
      (expand-file-name "transient/values.el" jackson/emacs-state-directory))
(setq transient-levels-file
      (expand-file-name "transient/levels.el" jackson/emacs-state-directory))

;; Narrowly persisted: known projects and bookmarks survive reboot via
;; ~/local/hacks/emacs/{projects,bookmarks}.
(setq project-list-file
      (expand-file-name "projects/projects.eld" jackson/emacs-hacks-directory))
(setq bookmark-default-file
      (expand-file-name "bookmarks/bookmarks" jackson/emacs-hacks-directory))

;; Customize storage. Declarative config is the source of truth, so route any
;; accidental `M-x customize-save-variable' writes into ephemeral state where
;; they will not be persisted.
(setq custom-file
      (expand-file-name "custom.el" jackson/emacs-state-directory))

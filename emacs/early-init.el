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
;; `user-emacs-directory' is a read-only /nix/store path. Subsystems that
;; would otherwise write next to init.el are redirected to ~/local/... .
;;
;; The directory defvars are defined here so they can be used by both
;; early-init.el and init.el. Most state-path setq's live in init.el next to
;; the configuration that depends on them; the native-comp eln-cache redirect
;; below is the exception, because the deferred-compilation worker can begin
;; writing .eln files before init.el is read.

(defvar jackson/emacs-state-directory
  (file-name-as-directory
   (expand-file-name "emacs"
                     (or (getenv "XDG_STATE_HOME")
                         (expand-file-name "~/local/state"))))
  "Emacs state under $XDG_STATE_HOME/emacs.
Backups and auto-saves under here are persisted across reboots; everything
else (auto-save-list, transient, custom, bookmarks) is intentionally
ephemeral.")

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

;; Native compilation cache. `startup-redirect-eln-cache' has to run before
;; native-comp loads, hence its placement in early-init.el rather than next to
;; the other state paths in init.el.
(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (expand-file-name "eln-cache/" jackson/emacs-cache-directory)))

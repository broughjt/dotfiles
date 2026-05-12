;;; -*- lexical-binding: t; -*-

;; Disable package.el. Emacs packages are managed by Nix.
(setq package-enable-at-startup nil)

;; typst-ts-mode 0.12.2's generated autoloads contain a top-level
;; `define-compilation-mode' form. If anything activates package autoloads
;; before compile.el is loaded, startup reports:
;;   Error loading autoloads: (void-function define-compilation-mode)
(require 'compile)

;; We start Emacs with `--init-directory <store-path>' so `user-emacs-directory'
;; sits in /nix/store and is read-only. Subsystems that would otherwise write
;; state next to init.el are redirected to ~/local/.
;;
;; We manage state redirections in init.el next to the configuration that
;; depends on them. However, since the native compilation eln-cache can begin
;; writing .eln files before init.el is even read, we set the directory
;; variables here and use the cache variable to configure the eln-cache before
;; init.el runs.

(defvar jackson/emacs-state-directory
  (file-name-as-directory
   (expand-file-name "emacs"
                     (or (getenv "XDG_STATE_HOME")
                         (error "XDG_STATE_HOME is not set; expected from PAM/systemd user environment"))))
  "Emacs state under $XDG_STATE_HOME/emacs.
Backups and auto-saves under here are persisted across reboots; everything
else (auto-save-list, transient, custom, bookmarks) is intentionally
ephemeral.")

(defvar jackson/emacs-cache-directory
  (file-name-as-directory
   (expand-file-name "emacs"
                     (or (getenv "XDG_CACHE_HOME")
                         (error "XDG_CACHE_HOME is not set; expected from PAM/systemd user environment"))))
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

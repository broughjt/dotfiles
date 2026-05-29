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
;; state next to init.el are redirected away from that read-only tree.
;;
;; On Linux, fail hard if the XDG environment is missing. murph deliberately
;; wires XDG_*_HOME into PAM/systemd very early, and a missing value means that
;; setup regressed.
;;
;; On macOS, there is no impermanence setup and GUI-launched apps may not see
;; shell/Home Manager session variables, so fall back to ordinary per-user XDG
;; locations.

(defvar jackson/emacs-state-directory
  (file-name-as-directory
   (expand-file-name
    "emacs"
    (file-name-as-directory
     (expand-file-name
      (or (getenv "XDG_STATE_HOME")
          (if (eq system-type 'darwin)
              "~/.local/state"
            (error "XDG_STATE_HOME is not set; expected from PAM/systemd user environment")))))))
  "Emacs state directory.
On Linux this is under $XDG_STATE_HOME/emacs and requires XDG_STATE_HOME to be
set. On macOS it falls back to ~/.local/state/emacs.")

(defvar jackson/emacs-cache-directory
  (file-name-as-directory
   (expand-file-name
    "emacs"
    (file-name-as-directory
     (expand-file-name
      (or (getenv "XDG_CACHE_HOME")
          (if (eq system-type 'darwin)
              "~/.cache"
            (error "XDG_CACHE_HOME is not set; expected from PAM/systemd user environment")))))))
  "Emacs cache directory.
On Linux this is under $XDG_CACHE_HOME/emacs and requires XDG_CACHE_HOME to be
set. On macOS it falls back to ~/.cache/emacs.")

(defvar jackson/emacs-hacks-directory
  (file-name-as-directory
   (if (eq system-type 'darwin)
       (expand-file-name "hacks" jackson/emacs-state-directory)
     (expand-file-name "~/local/hacks/emacs")))
  "Narrowly persisted Emacs state, such as the known-projects list.
On Linux this remains ~/local/hacks/emacs. On macOS it falls back under the
normal Emacs state directory.")

;; Native compilation cache. `startup-redirect-eln-cache' has to run before
;; native compilation loads, which is why we place it in early-init.el rather
;; than next to the other state configuration in init.el.
(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (expand-file-name "eln-cache/" jackson/emacs-cache-directory)))

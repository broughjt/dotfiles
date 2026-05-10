;;; -*- lexical-binding: t; -*-

;; Disable package.el's automatic package activation. Packages are supplied by
;; Nix and configured explicitly from init.el with use-package.
(setq package-enable-at-startup nil)

;; typst-ts-mode 0.12.2's generated autoloads contain a top-level
;; `define-compilation-mode' form. If anything activates package autoloads
;; before compile.el is loaded, startup reports:
;;   Error loading autoloads: (void-function define-compilation-mode)
(require 'compile)

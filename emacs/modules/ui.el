;;; -*- lexical-binding: t; -*-

(menu-bar-mode 0)
(tool-bar-mode 0)
(scroll-bar-mode 0)

(require 'display-line-numbers)

(set-face-attribute 'default nil :family "JuliaMono" :height 100)

(setq visible-bell t)

(setq-default display-line-numbers-type 'visual)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)

(setq-default indent-tabs-mode nil)

(setq-default fill-column 80)
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)
(add-hook 'text-mode-hook #'display-fill-column-indicator-mode)

(use-package standard-themes)
(use-package modus-themes)
(use-package ef-themes
  :config
  (load-theme 'ef-dark t))

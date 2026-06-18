;;; -*- lexical-binding: t; -*-

(menu-bar-mode 0)
(tool-bar-mode 0)
(scroll-bar-mode 0)

(require 'display-line-numbers)

(set-face-attribute
 'default nil
 :family "JuliaMono" :height (if (eq system-type 'darwin) 140 120))

(setq visible-bell t)

(setq-default display-line-numbers-type 'visual)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)

(setq-default indent-tabs-mode nil)

(setq-default fill-column 80)
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)
(add-hook 'text-mode-hook #'display-fill-column-indicator-mode)

(declare-function visual-wrap-prefix-mode "simple" (&optional arg))

(defun jackson/soft-wrap-markup ()
  "Use non-mutating soft wrapping for prose-oriented markup buffers."
  (visual-line-mode 1)
  (when (fboundp 'visual-wrap-prefix-mode)
    (visual-wrap-prefix-mode 1))
  (auto-fill-mode -1)
  (setq-local truncate-lines nil)
  (display-fill-column-indicator-mode -1))

(dolist (hook '(typst-ts-mode-hook
                TeX-mode-hook
                LaTeX-mode-hook
                markdown-mode-hook
                gfm-mode-hook
                org-mode-hook
                rst-mode-hook
                texinfo-mode-hook))
  (add-hook hook #'jackson/soft-wrap-markup))

(use-package standard-themes
  :config
  (load-theme 'standard-dark t))
(use-package modus-themes)
(use-package ef-themes)

(provide 'ui)

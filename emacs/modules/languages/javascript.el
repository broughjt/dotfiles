;;; -*- lexical-binding: t; -*-

(use-package js
  :custom
  (js-indent-level 2))

(add-to-list 'auto-mode-alist '("\\.js\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.mjs\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.cjs\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.mts\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.jsx\\'" . tsx-ts-mode))
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
(add-to-list 'auto-mode-alist '("\\.json\\'" . json-ts-mode))
(add-hook 'typescript-ts-mode-hook 'eglot-ensure)
(add-hook 'tsx-ts-mode-hook 'eglot-ensure)

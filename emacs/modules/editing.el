;;; -*- lexical-binding: t; -*-

(eval-and-compile
  (defvar evil-want-keybinding)
  (setq evil-want-keybinding nil))

(declare-function evil-mode "evil" (&optional arg))
(declare-function evil-collection-init "evil-collection")

(use-package evil
 :init
 :custom
 (evil-undo-system 'undo-redo)
 :config
 (evil-mode 1))

(use-package evil-collection
 :after evil
 :config
 (evil-collection-init))

(use-package magit)

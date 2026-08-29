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
 :custom
 ;; Keep h/l as horizontal motion in magit buffers. Magit's "h"
 ;; (`magit-dispatch') and "l" (`magit-log') move to "H" and "L".
 (evil-collection-magit-want-horizontal-movement t)
 :config
 (evil-collection-init))

(provide 'editing)

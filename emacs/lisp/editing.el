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

(defun jackson/magit-soft-wrap ()
  "Wrap long lines in Magit buffers that show diff hunks.
`magit-section-mode' turns on `truncate-lines'; diffs of long lines are
then only reachable by scrolling horizontally."
  (setq-local truncate-lines nil))

(use-package magit
 :custom
 ;; Highlight the word-level differences between the removed and added
 ;; lines of a hunk.
 (magit-diff-refine-hunk 'all)
 :hook ((magit-status-mode . jackson/magit-soft-wrap)
        (magit-diff-mode . jackson/magit-soft-wrap)
        (magit-revision-mode . jackson/magit-soft-wrap)))

(provide 'editing)

;;; -*- lexical-binding: t; -*-

(defun jackson/magit-soft-wrap ()
  "Wrap long lines in Magit buffers that show diff hunks.
`magit-section-mode' turns on `truncate-lines'; diffs of long lines are
then only reachable by scrolling horizontally."
  (setq-local truncate-lines nil))

(use-package magit
 :demand t
 :custom
 ;; Highlight the word-level differences between the removed and added
 ;; lines of a hunk.
 (magit-diff-refine-hunk 'all)
 :hook ((magit-status-mode . jackson/magit-soft-wrap)
        (magit-diff-mode . jackson/magit-soft-wrap)
        (magit-revision-mode . jackson/magit-soft-wrap)))

(provide 'git-config)

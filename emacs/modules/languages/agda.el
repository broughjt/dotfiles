(defun jackson/agda-locate ()
  "Run `agda --emacs-mode locate` and echo the results."
  (interactive)
  (let ((coding-system-for-read 'utf-8))
    (load-file (shell-command-to-string "agda --emacs-mode locate"))))

(setq agda2-highlight-level 'interactive)

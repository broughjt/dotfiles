;;; -*- lexical-binding: t; -*-

(require 'inheritenv)

(defun jackson/agda-locate ()
  "Load Agda mode from the path printed by `agda --emacs-mode locate`."
  (interactive)
  (let* ((coding-system-for-read 'utf-8)
         (agda-mode-path
          (string-trim
           (inheritenv
            (shell-command-to-string "agda --emacs-mode locate")))))
    (unless (file-readable-p agda-mode-path)
      (user-error "Agda locate failed; expected readable path, got: %s"
                  agda-mode-path))
    (load-file agda-mode-path)))

(defvar agda2-highlight-level)

(setq agda2-highlight-level 'interactive)

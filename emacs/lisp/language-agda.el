;;; -*- lexical-binding: t; -*-

(require 'inheritenv)

(defun jackson/agda--command-output (directory program &rest arguments)
  "Run PROGRAM with ARGUMENTS in DIRECTORY and return its standard output."
  (let ((stderr-file (make-temp-file "agda-locate-stderr-")))
    (unwind-protect
        (with-temp-buffer
          (setq default-directory directory)
          (let* ((status
                  (apply #'process-file
                         program nil (list t stderr-file) nil arguments))
                 (stdout (string-trim (buffer-string))))
            (unless (equal status 0)
              (let ((stderr
                     (with-temp-buffer
                       (insert-file-contents stderr-file)
                       (string-trim (buffer-string)))))
                (user-error
                 "%s failed with status %s%s"
                 (mapconcat #'shell-quote-argument
                            (cons program arguments) " ")
                 status
                 (if (string-empty-p (concat stdout stderr))
                     ""
                   (format ": %s"
                           (cond
                            ((string-empty-p stdout) stderr)
                            ((string-empty-p stderr) stdout)
                            (t (concat stdout "\n" stderr))))))))
            stdout))
      (delete-file stderr-file))))

(defun jackson/agda--locate-command ()
  "Return (DIRECTORY PROGRAM . ARGUMENTS) for locating Agda mode."
  (let ((remote (file-remote-p default-directory)))
    (if (executable-find "agda" remote)
        (list default-directory "agda" "--emacs-mode" "locate")
      (if-let* ((flake-directory
                 (locate-dominating-file default-directory "flake.nix")))
          (progn
            (unless (executable-find "nix" remote)
              (user-error "Agda is absent and nix is not available"))
            (list flake-directory
                  "nix" "develop" "--no-write-lock-file" "--command"
                  "agda" "--emacs-mode" "locate"))
        (user-error "Agda is absent and no flake.nix was found above %s"
                    default-directory)))))

(defun jackson/agda--mode-file (path directory)
  "Return Agda mode PATH as seen from DIRECTORY."
  (unless (file-name-absolute-p path)
    (user-error "Agda locate returned a relative path: %s" path))
  (if-let* ((remote (file-remote-p directory)))
      (concat remote path)
    path))

(defun jackson/agda-locate ()
  "Load the Agda mode belonging to the current project.
Use Agda from the inherited environment when available.  Otherwise, run it
through the nearest flake's default development shell."
  (interactive)
  (let ((coding-system-for-read 'utf-8))
    (inheritenv
     (pcase-let* ((`(,directory ,program . ,arguments)
                    (jackson/agda--locate-command))
                   (agda-mode-path
                    (jackson/agda--mode-file
                     (apply #'jackson/agda--command-output
                            directory program arguments)
                     directory)))
       (unless (file-readable-p agda-mode-path)
         (user-error "Agda locate failed; expected readable path, got: %s"
                     agda-mode-path))
       (load-file agda-mode-path)))))

(defvar agda2-highlight-level)

(setq agda2-highlight-level 'interactive)

(provide 'language-agda)

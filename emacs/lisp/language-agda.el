;;; -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'inheritenv)

;; Agda mode is not a package installed alongside the others: every Agda ships
;; the Emacs mode matching it, and `agda --emacs-mode locate' prints where.  So
;; the mode is loaded at run time from whichever Agda the project pins, and the
;; interaction process has to come from that same Agda.  When there is no Agda
;; in the environment, both are taken from the nearest flake's development
;; shell.

(defun jackson/agda--command-output (directory program &rest arguments)
  "Run PROGRAM with ARGUMENTS in DIRECTORY and return its standard output."
  (let ((stderr-file (make-temp-file "agda-locate-stderr-")))
    (unwind-protect
        (with-temp-buffer
          (setq default-directory directory)
          (let* ((status
                  (apply #'call-process
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

(defun jackson/agda--command-prefix ()
  "Return (DIRECTORY . PREFIX) for running Agda for the current buffer.
DIRECTORY is where Agda should run, and PREFIX is a command prefix to put
in front of it, empty when Agda is inherited from the environment."
  (if (executable-find "agda")
      (cons default-directory nil)
    (if-let* ((flake-directory
               (locate-dominating-file default-directory "flake.nix")))
        (progn
          (unless (executable-find "nix")
            (user-error "Agda is absent and nix is not available"))
          ;; --no-write-lock-file so that merely loading the mode cannot
          ;; edit the project's lock file.
          (cons flake-directory
                (list "nix" "develop" "--no-write-lock-file" "--command")))
      (user-error "Agda is absent and no flake.nix was found above %s"
                  default-directory))))

(defun jackson/agda--restart (restart)
  "Call RESTART with Agda's process calls sent through the project.
Agda mode starts three processes here: a version check, a check that the
mode and the executable agree, and the long-lived interaction process.
Each names `agda2-program-name' directly, so each is given the project's
command prefix instead, and runs inside that project's development shell."
  (pcase-let ((`(,directory . ,prefix) (jackson/agda--command-prefix)))
    (let ((default-directory directory)
          (call (symbol-function 'call-process))
          (start (symbol-function 'start-process)))
      (cl-letf
          (((symbol-function 'call-process)
            (lambda (program &optional infile buffer display &rest arguments)
              (let ((command (append prefix (cons program arguments))))
                (apply call (car command) infile buffer display (cdr command)))))
           ((symbol-function 'start-process)
            (lambda (name buffer program &rest arguments)
              (apply start name buffer (append prefix (cons program arguments))))))
        (funcall restart)))))

(defun jackson/agda-locate ()
  "Load the Agda mode belonging to the current project.
Use Agda from the inherited environment when available.  Otherwise, run it
through the nearest flake's default development shell."
  (interactive)
  (let ((coding-system-for-read 'utf-8))
    (inheritenv
     (pcase-let* ((`(,directory . ,prefix) (jackson/agda--command-prefix))
                  (locate (append prefix '("agda" "--emacs-mode" "locate")))
                  (agda-mode-path
                   (apply #'jackson/agda--command-output directory locate)))
       (unless (file-readable-p agda-mode-path)
         (user-error "Agda locate failed; expected readable path, got: %s"
                     agda-mode-path))
       (load-file agda-mode-path)
       (advice-add 'agda2-restart :around #'jackson/agda--restart)))))

(defvar agda2-highlight-level)

(setq agda2-highlight-level 'interactive)

(provide 'language-agda)

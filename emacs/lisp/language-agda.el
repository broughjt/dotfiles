;;; -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'inheritenv)

;; Upstream Agda mode assumes Agda runs on the machine Emacs runs on: it uses
;; `call-process' and `start-process', and it puts raw `buffer-file-name'
;; values into the protocol. None of that holds for a file visited over Tramp.
;; The mode is loaded at run time from whichever Agda the project pins, so it
;; cannot be patched; it is adapted here instead, at the three boundaries where
;; a machine is implied: process creation, commands sent to Agda, and file
;; names Agda sends back.

(defvar agda2-directory)

(defvar jackson/agda--connection nil
  "Tramp prefix of the machine the Agda process runs on, nil when local.
Set whenever the process is started, so it names the machine Agda's own
file names belong to rather than whatever buffer happens to be current.")

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

(defun jackson/agda--command-prefix ()
  "Return (DIRECTORY . PREFIX) for running Agda for the current buffer.
DIRECTORY is where Agda should run, and PREFIX is a command prefix to put
in front of it, empty when Agda is inherited from the environment."
  (let ((remote (file-remote-p default-directory)))
    (if (executable-find "agda" remote)
        (cons default-directory nil)
      (if-let* ((flake-directory
                 (locate-dominating-file default-directory "flake.nix")))
          (progn
            (unless (executable-find "nix" remote)
              (user-error "Agda is absent and nix is not available"))
            ;; --no-write-lock-file so that merely loading the mode cannot
            ;; edit the project's lock file.
            (cons flake-directory
                  (list "nix" "develop" "--no-write-lock-file" "--command")))
        (user-error "Agda is absent and no flake.nix was found above %s"
                    default-directory)))))

(defun jackson/agda--mode-file (path directory)
  "Return Agda mode PATH as seen from DIRECTORY."
  (unless (file-name-absolute-p path)
    (user-error "Agda locate returned a relative path: %s" path))
  (if-let* ((remote (file-remote-p directory)))
      (concat remote path)
    path))

;;;; Process creation

(defun jackson/agda--restart (restart)
  "Call RESTART with Agda's process calls redirected at the project.
Agda mode starts three processes here: two preflight checks and the
long-lived interaction process.  Each is rerouted through `process-file'
and `start-file-process', so it runs on the machine holding the file, and
each is given the project's command prefix, so it runs inside that
project's development shell.

Tramp serves those remote calls by opening a connection, and it opens one
with `start-process' itself, so the replacements stand aside for anything
they are already serving.  Without that, Tramp's own login would be sent
back through Tramp until Lisp nesting ran out."
  (pcase-let ((`(,directory . ,prefix) (jackson/agda--command-prefix)))
    (setq jackson/agda--connection (file-remote-p directory))
    (let ((default-directory directory)
          (serving nil)
          (call (symbol-function 'call-process))
          (start (symbol-function 'start-process)))
      (cl-letf
          (((symbol-function 'call-process)
            (lambda (program &optional infile buffer display &rest arguments)
              (if serving
                  (apply call program infile buffer display arguments)
                (let ((command (append prefix (cons program arguments))))
                  (unwind-protect
                      (progn
                        (setq serving t)
                        (apply #'process-file
                               (car command) infile buffer display
                               (cdr command)))
                    (setq serving nil))))))
           ((symbol-function 'start-process)
            (lambda (name buffer program &rest arguments)
              (if serving
                  (apply start name buffer program arguments)
                (let ((command (append prefix (cons program arguments))))
                  (unwind-protect
                      (progn
                        (setq serving t)
                        (apply #'start-file-process name buffer command))
                    (setq serving nil)))))))
        (funcall restart)))))

;;;; File names crossing the protocol

(defun jackson/agda--send-command (arguments)
  "Strip the Tramp prefix from file names in ARGUMENTS.
Agda mode quotes `buffer-file-name' straight into its commands, so a
remote buffer sends Emacs' own name for the file to an Agda that has
never heard of it.  Only a prefix directly opening a Haskell string
literal is rewritten, so ordinary text that mentions one is left alone."
  (if-let* ((connection jackson/agda--connection))
      (cons (car arguments)
            (mapcar (lambda (argument)
                      (if (stringp argument)
                          (string-replace (concat "\"" connection) "\"" argument)
                        argument))
                    (cdr arguments)))
    arguments))

(defun jackson/agda--remote-name (path)
  "Return Agda's PATH as Emacs sees it from here.
A path that is already remote is returned unchanged, so that names Emacs
handed to Agda mode itself survive a round trip."
  (if (and jackson/agda--connection
           (stringp path)
           (not (file-remote-p path)))
      (concat jackson/agda--connection path)
    path))

(defun jackson/agda--remote-file (arguments)
  "Rewrite the leading file name in ARGUMENTS."
  (cons (jackson/agda--remote-name (car arguments)) (cdr arguments)))

(defun jackson/agda--remote-filepos (arguments)
  "Rewrite the file name in the leading (FILE . POSITION) of ARGUMENTS."
  (let ((filepos (car arguments)))
    (cons (if (consp filepos)
              (cons (jackson/agda--remote-name (car filepos)) (cdr filepos))
            filepos)
          (cdr arguments))))

(defun jackson/agda--adapt ()
  "Teach the Agda mode just loaded to work over Tramp.
Only the restart is always adapted, since a local Agda needs the project's
development shell too.  The file name translation is inert while
`jackson/agda--connection' is nil."
  (advice-add 'agda2-restart :around #'jackson/agda--restart)
  (advice-add 'agda2-send-command :filter-args #'jackson/agda--send-command)
  ;; Highlighting arrives indirectly, as a file Agda writes and Emacs reads
  ;; and deletes, so both halves of that happen on Agda's machine.
  (advice-add 'agda2-highlight-load :filter-args #'jackson/agda--remote-file)
  (advice-add 'agda2-highlight-load-and-delete-action
              :filter-args #'jackson/agda--remote-file)
  ;; Jumping to a definition or an error, whether from a response or from a
  ;; highlighting annotation under point.
  (advice-add 'annotation-goto :filter-args #'jackson/agda--remote-filepos)
  (advice-add 'agda2-maybe-goto :filter-args #'jackson/agda--remote-filepos))

;;;; Entry point

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
                   (jackson/agda--mode-file
                    (apply #'jackson/agda--command-output directory locate)
                    directory)))
       (unless (file-readable-p agda-mode-path)
         (user-error "Agda locate failed; expected readable path, got: %s"
                     agda-mode-path))
       ;; agda2.el derives `agda2-directory' from `load-file-name', which for a
       ;; remote file is the local copy Tramp loads through, a directory with
       ;; none of agda2.el's siblings in it. Setting it first wins, because
       ;; agda2.el declares it with `defvar'.
       (setq agda2-directory (file-name-directory agda-mode-path))
       (load-file agda-mode-path)
       (jackson/agda--adapt)))))

(defvar agda2-highlight-level)

(setq agda2-highlight-level 'interactive)

(provide 'language-agda)

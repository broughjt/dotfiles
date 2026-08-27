;;; -*- lexical-binding: t; -*-

;; A Tramp method for Fly sprites, modeled on the container methods in
;; tramp-container.el. `sprite exec -s NAME -- /bin/sh' is a clean pipe, which
;; is the only property those methods rely on, so we don't need sshd in the
;; sprite.

(defconst sprite-tramp-method "sprite"
  "Tramp method name for connecting to a sprite.")

(defcustom sprite-program "sprite"
  "Name of the sprite CLI, looked up on `exec-path'."
  :type 'string
  :group 'tramp)

(defun sprite-tramp--completion-function (_method)
  "Return the sprites available for connection.
Used by `tramp-set-completion-function'; see its documentation for
the format."
  (mapcar
   (lambda (name) (list nil name))
   ;; `sprite list' prints one bare name per line. Anything else is an error
   ;; message rather than a sprite, so drop it instead of offering it.
   (seq-filter
    (lambda (line) (string-match-p (rx bos (+ (any alnum ?- ?_)) eos) line))
    (split-string
     (shell-command-to-string (concat sprite-program " list")) "\n" t))))

(use-package tramp
  :demand t
  :config
  (add-to-list 'tramp-methods
               `(,sprite-tramp-method
                 (tramp-login-program ,sprite-program)
                 ;; --tty because Tramp drives an interactive shell and
                 ;; synchronizes on its prompt; without a terminal the shell
                 ;; warns about job control and never settles. TERM comes along
                 ;; for the same reason docker's method sends it, to keep the
                 ;; shell from emitting escape sequences at a dumb terminal.
                 (tramp-login-args (("exec")
                                    ("--tty")
                                    ("--env" ,(format "TERM=%s" tramp-terminal-type))
                                    ("-s" "%h")
                                    ("--")
                                    ("%l")))
                 (tramp-remote-shell ,tramp-default-remote-shell)
                 (tramp-remote-shell-login ("-l"))
                 (tramp-remote-shell-args ("-i" "-c"))
                 ;; Sprites come and go by hand, and the list is one cheap
                 ;; call, so completion should not serve a stale one.
                 (tramp-completion-use-cache nil)))
  (tramp-set-completion-function
   sprite-tramp-method '((sprite-tramp--completion-function "")))
  ;; Tramp falls back to `getconf PATH' here, which yields /bin:/usr/bin and
  ;; so misses the Nix binaries sprite-provision links into ~/.local/bin.
  ;; Without this, remote commands cannot see nix at all. Scoped to this
  ;; method rather than set globally, since `tramp-remote-path' is otherwise
  ;; shared with every other connection. A tilde is not expanded here, hence
  ;; taking the sprite's own PATH instead of naming the directory.
  (connection-local-set-profile-variables
   'sprite-tramp-profile
   `((tramp-remote-path . ,(cons 'tramp-own-remote-path tramp-remote-path))))
  (connection-local-set-profiles
   '(:application tramp :protocol "sprite") 'sprite-tramp-profile))

(provide 'sprite-config)

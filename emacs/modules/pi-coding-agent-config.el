;;; -*- lexical-binding: t; -*-

(defvar jackson/pi-coding-agent-input-auto-enabled t
  "Non-nil when pi input windows automatically follow visible chat windows.")
(defvar jackson/pi-coding-agent-input--pending nil
  "Pending timer for pi input-window synchronization.")
(defvar jackson/pi-coding-agent-input--busy nil
  "Non-nil while pi input-window synchronization is running.")

(declare-function pi-coding-agent--get-chat-buffer "pi-coding-agent-ui")
(declare-function pi-coding-agent--get-input-buffer "pi-coding-agent-ui")
(declare-function pi-coding-agent--input-height-for-window "pi-coding-agent-ui")
(declare-function pi-coding-agent--window-can-split-for-input-p "pi-coding-agent-ui")

(defun jackson/pi-coding-agent-current-chat (&optional buffer)
  "Return BUFFER's associated pi chat buffer or nil."
  (let ((buffer (or buffer (current-buffer))))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (when (derived-mode-p 'pi-coding-agent-chat-mode
                              'pi-coding-agent-input-mode)
          (let ((chat (pi-coding-agent--get-chat-buffer)))
            (and (buffer-live-p chat) chat)))))))

(defun jackson/pi-coding-agent-current-input (&optional chat)
  "Return CHAT's associated pi input buffer or nil."
  (let ((chat (or chat (jackson/pi-coding-agent-current-chat))))
    (when (buffer-live-p chat)
      (with-current-buffer chat
        (let ((input (pi-coding-agent--get-input-buffer)))
          (and (buffer-live-p input) input))))))

(defun jackson/pi-coding-agent-input-visible-p (&optional chat)
  "Return non-nil when CHAT's pi input buffer is visible in the current frame."
  (when-let* ((input (jackson/pi-coding-agent-current-input chat)))
    (get-buffer-window input nil)))

(defun jackson/pi-coding-agent-visible-chat (&optional frame preferred)
  "Return a visible pi chat buffer in FRAME, preferring PREFERRED."
  (let ((frame (or frame (selected-frame))))
    (or (and (buffer-live-p preferred)
             (get-buffer-window preferred frame)
             preferred)
        (let (found)
          (dolist (window (window-list frame 'no-minibuf) found)
            (let ((buffer (window-buffer window)))
              (when (with-current-buffer buffer
                      (derived-mode-p 'pi-coding-agent-chat-mode))
                (setq found buffer))))))))

(defun jackson/pi-coding-agent-input--last-chat (&optional frame)
  "Return FRAME's last visible pi chat buffer."
  (frame-parameter frame 'jackson/pi-coding-agent-input--last-chat))

(defun jackson/pi-coding-agent-input--set-last-chat (chat &optional frame)
  "Set CHAT as FRAME's last visible pi chat buffer."
  (set-frame-parameter frame 'jackson/pi-coding-agent-input--last-chat chat))

(defun jackson/pi-coding-agent-input--suppressed-chat (&optional frame)
  "Return FRAME's manually hidden pi chat buffer, or nil."
  (frame-parameter frame 'jackson/pi-coding-agent-input--suppressed-chat))

(defun jackson/pi-coding-agent-input--set-suppressed-chat (chat &optional frame)
  "Set CHAT as FRAME's manually hidden pi chat buffer."
  (set-frame-parameter frame 'jackson/pi-coding-agent-input--suppressed-chat chat))

(defun jackson/pi-coding-agent-hide-input (&optional chat manual)
  "Delete CHAT's pi input windows in the selected frame.
When MANUAL is non-nil, keep automatic sync from reopening the input window
until this frame leaves and re-enters the pi session."
  (let ((chat (or chat (jackson/pi-coding-agent-current-chat))))
    (when (buffer-live-p chat)
      (when manual
        (jackson/pi-coding-agent-input--set-suppressed-chat chat))
      (when-let* ((input (jackson/pi-coding-agent-current-input chat)))
        (dolist (window (get-buffer-window-list input nil))
          (ignore-errors (delete-window window)))))))

(defun jackson/pi-coding-agent-show-input (&optional chat manual)
  "Show CHAT's pi input buffer below its selected-frame chat window.
When MANUAL is non-nil, clear any manual suppression for this frame."
  (let* ((chat (or chat (jackson/pi-coding-agent-current-chat)))
         (input (jackson/pi-coding-agent-current-input chat))
         (chat-window (and (buffer-live-p chat) (get-buffer-window chat nil))))
    (when manual
      (jackson/pi-coding-agent-input--set-suppressed-chat nil))
    (when (and (buffer-live-p input)
               (window-live-p chat-window)
               (not (get-buffer-window input nil))
               (pi-coding-agent--window-can-split-for-input-p chat-window))
      (let ((input-window
             (split-window chat-window
                           (- (pi-coding-agent--input-height-for-window
                               chat-window))
                           'below)))
        (set-window-buffer input-window input)
        (set-window-dedicated-p input-window 'side)))))

(defun jackson/pi-coding-agent-toggle-input ()
  "Toggle the current pi session's input window."
  (interactive)
  (let ((chat (or (jackson/pi-coding-agent-current-chat)
                  (jackson/pi-coding-agent-visible-chat))))
    (unless chat
      (user-error "No visible pi session"))
    (if (jackson/pi-coding-agent-input-visible-p chat)
        (jackson/pi-coding-agent-hide-input chat t)
      (jackson/pi-coding-agent-show-input chat t))))

(defun jackson/pi-coding-agent-toggle-input-auto (&optional arg)
  "Toggle automatic pi input-window management.
With prefix ARG, enable when ARG is positive and disable otherwise."
  (interactive "P")
  (setq jackson/pi-coding-agent-input-auto-enabled
        (if arg
            (> (prefix-numeric-value arg) 0)
          (not jackson/pi-coding-agent-input-auto-enabled)))
  (if jackson/pi-coding-agent-input-auto-enabled
      (progn
        (jackson/pi-coding-agent-input--schedule)
        (message "Pi input auto-follow enabled"))
    (when (timerp jackson/pi-coding-agent-input--pending)
      (cancel-timer jackson/pi-coding-agent-input--pending)
      (setq jackson/pi-coding-agent-input--pending nil))
    (message "Pi input auto-follow disabled")))

(defun jackson/pi-coding-agent-input--sync ()
  "Synchronize pi input-window visibility with the selected window."
  (setq jackson/pi-coding-agent-input--pending nil)
  (unless (or (not jackson/pi-coding-agent-input-auto-enabled)
              jackson/pi-coding-agent-input--busy
              (minibufferp (window-buffer (selected-window))))
    (let ((jackson/pi-coding-agent-input--busy t))
      (condition-case err
          (let* ((frame (selected-frame))
                 (buffer (window-buffer (selected-window)))
                 (selected-chat (jackson/pi-coding-agent-current-chat buffer))
                 (last-chat (jackson/pi-coding-agent-input--last-chat frame))
                 (visible-chat (jackson/pi-coding-agent-visible-chat
                                frame (or selected-chat last-chat))))
            (if visible-chat
                (progn
                  (unless (eq visible-chat last-chat)
                    (jackson/pi-coding-agent-hide-input last-chat))
                  (jackson/pi-coding-agent-input--set-last-chat visible-chat frame)
                  (unless (eq visible-chat
                              (jackson/pi-coding-agent-input--suppressed-chat
                               frame))
                    (jackson/pi-coding-agent-show-input visible-chat)))
              (jackson/pi-coding-agent-hide-input last-chat)
              (jackson/pi-coding-agent-input--set-last-chat nil frame)
              (jackson/pi-coding-agent-input--set-suppressed-chat nil frame)))
        (error
         (message "pi auto input: %s" (error-message-string err)))))))

(defun jackson/pi-coding-agent-input--schedule (&rest _)
  "Schedule `jackson/pi-coding-agent-input--sync' to run as soon as soon as
the redisplay-related code has finished."
  ;; I don't actually know what the "redisplay-related code" is--an agent
  ;; recommended doing it this way and I haven't dug deeper.
  ;;
  ;; I think the idea is that timers are not preemptive. They get registered,
  ;; and Emacs will run the function once it gets to the part of the interaction
  ;; loop that runs timers. So the idea here is that the redisplay/window
  ;; bookkeeping code will run, and then `jackson/pi-coding-agent-input--sync'
  ;; will run.
  (when jackson/pi-coding-agent-input-auto-enabled
    (unless (timerp jackson/pi-coding-agent-input--pending)
      (setq jackson/pi-coding-agent-input--pending
            (run-at-time nil nil #'jackson/pi-coding-agent-input--sync)))))

(use-package pi-coding-agent
  :commands
  (pi-coding-agent
   pi-coding-agent-install-grammars
   pi-coding-agent-switch-to-chat-buffer
   pi-coding-agent-switch-to-project-chat-buffer
   pi-coding-agent-toggle)
  :bind
  (("C-c a b" . pi-coding-agent-switch-to-chat-buffer)
   ("C-c a k" . pi-coding-agent-kill-chat-buffer)
   ("C-c a t" . jackson/pi-coding-agent-toggle-input-auto)
   ("C-x p P" . pi-coding-agent-switch-to-project-chat-buffer))
  :config
  (add-hook 'window-buffer-change-functions
            #'jackson/pi-coding-agent-input--schedule))

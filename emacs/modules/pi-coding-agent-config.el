;;; -*- lexical-binding: t; -*-

(defvar my/pi-coding-agent-auto-input--pending nil
  "Pending timer for pi input-window synchronization.")
(defvar my/pi-coding-agent-auto-input--busy nil
  "Non-nil while pi input-window synchronization is running.")

(declare-function pi-coding-agent--get-chat-buffer "pi-coding-agent-ui")
(declare-function pi-coding-agent--get-input-buffer "pi-coding-agent-ui")
(declare-function pi-coding-agent--input-height-for-window "pi-coding-agent-ui")
(declare-function pi-coding-agent--window-can-split-for-input-p "pi-coding-agent-ui")

(defun my/pi-coding-agent-current-chat (&optional buffer)
  "Return BUFFER's linked pi chat buffer, or nil.
When BUFFER is nil, use the current buffer."
  (let ((buffer (or buffer (current-buffer))))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (when (derived-mode-p 'pi-coding-agent-chat-mode
                              'pi-coding-agent-input-mode)
          (let ((chat (pi-coding-agent--get-chat-buffer)))
            (and (buffer-live-p chat) chat)))))))

(defun my/pi-coding-agent-current-input (&optional chat)
  "Return CHAT's linked pi input buffer, or nil.
When CHAT is nil, use the current pi session."
  (let ((chat (or chat (my/pi-coding-agent-current-chat))))
    (when (buffer-live-p chat)
      (with-current-buffer chat
        (let ((input (pi-coding-agent--get-input-buffer)))
          (and (buffer-live-p input) input))))))

(defun my/pi-coding-agent-input-visible-p (&optional chat)
  "Return non-nil when CHAT's pi input buffer is visible in this frame."
  (when-let* ((input (my/pi-coding-agent-current-input chat)))
    (get-buffer-window input nil)))

(defun my/pi-coding-agent-auto-input--last-chat (&optional frame)
  "Return FRAME's last selected pi chat buffer."
  (frame-parameter frame 'my/pi-coding-agent-auto-input--last-chat))

(defun my/pi-coding-agent-auto-input--set-last-chat (chat &optional frame)
  "Remember CHAT as FRAME's last selected pi chat buffer."
  (set-frame-parameter frame 'my/pi-coding-agent-auto-input--last-chat chat))

(defun my/pi-coding-agent-auto-input--suppressed-chat (&optional frame)
  "Return FRAME's manually hidden pi chat buffer, or nil."
  (frame-parameter frame 'my/pi-coding-agent-auto-input--suppressed-chat))

(defun my/pi-coding-agent-auto-input--set-suppressed-chat (chat &optional frame)
  "Remember CHAT as FRAME's manually hidden pi chat buffer."
  (set-frame-parameter frame 'my/pi-coding-agent-auto-input--suppressed-chat chat))

(defun my/pi-coding-agent-hide-input (&optional chat manual)
  "Delete CHAT's pi input windows in the selected frame.
When MANUAL is non-nil, keep automatic sync from reopening the input window
until this frame leaves and re-enters the pi session."
  (let ((chat (or chat (my/pi-coding-agent-current-chat))))
    (when (buffer-live-p chat)
      (when manual
        (my/pi-coding-agent-auto-input--set-suppressed-chat chat))
      (when-let* ((input (my/pi-coding-agent-current-input chat)))
        (dolist (window (get-buffer-window-list input nil))
          (ignore-errors (delete-window window)))))))

(defun my/pi-coding-agent-show-input (&optional chat manual)
  "Show CHAT's pi input buffer below its selected-frame chat window.
When MANUAL is non-nil, clear any manual suppression for this frame."
  (let* ((chat (or chat (my/pi-coding-agent-current-chat)))
         (input (my/pi-coding-agent-current-input chat))
         (chat-window (and (buffer-live-p chat) (get-buffer-window chat nil))))
    (when manual
      (my/pi-coding-agent-auto-input--set-suppressed-chat nil))
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

(defun my/pi-coding-agent-toggle-input ()
  "Toggle the current pi session's input window."
  (interactive)
  (let ((chat (my/pi-coding-agent-current-chat)))
    (unless chat
      (user-error "Not in a pi session"))
    (if (my/pi-coding-agent-input-visible-p chat)
        (progn
          (my/pi-coding-agent-hide-input chat t)
          (message "Pi input hidden"))
      (my/pi-coding-agent-show-input chat t)
      (message "Pi input shown"))))

(defun my/pi-coding-agent-auto-input--sync ()
  "Synchronize pi input-window visibility with the selected window."
  (setq my/pi-coding-agent-auto-input--pending nil)
  (unless (or my/pi-coding-agent-auto-input--busy
              (minibufferp (window-buffer (selected-window))))
    (let ((my/pi-coding-agent-auto-input--busy t))
      (condition-case err
          (let* ((frame (selected-frame))
                 (buffer (window-buffer (selected-window)))
                 (chat (my/pi-coding-agent-current-chat buffer))
                 (last-chat (my/pi-coding-agent-auto-input--last-chat frame)))
            (cond
             (chat
              (unless (eq chat last-chat)
                (my/pi-coding-agent-hide-input last-chat))
              (my/pi-coding-agent-auto-input--set-last-chat chat frame)
              (with-current-buffer buffer
                (when (and (derived-mode-p 'pi-coding-agent-chat-mode)
                           (not (eq chat
                                    (my/pi-coding-agent-auto-input--suppressed-chat
                                     frame))))
                  (my/pi-coding-agent-show-input chat))))
             (t
              (my/pi-coding-agent-hide-input last-chat)
              (my/pi-coding-agent-auto-input--set-last-chat nil frame)
              (my/pi-coding-agent-auto-input--set-suppressed-chat nil frame))))
        (error
         (message "pi auto input: %s" (error-message-string err)))))))

(defun my/pi-coding-agent-auto-input--schedule (&rest _)
  "Schedule pi input-window synchronization after window changes settle."
  (unless (timerp my/pi-coding-agent-auto-input--pending)
    (setq my/pi-coding-agent-auto-input--pending
          (run-at-time 0 nil #'my/pi-coding-agent-auto-input--sync))))

(use-package pi-coding-agent
  :commands
  (pi-coding-agent pi-coding-agent-toggle pi-coding-agent-install-grammars)
  :bind
  ("C-c p t" . my/pi-coding-agent-toggle-input)
  :config
  ;; Keep pi's prompt buffer paired with the selected chat buffer, but hide
  ;; just the prompt window when leaving the pi session.  These hooks are more
  ;; specific than `post-command-hook': they fire when window selection changes
  ;; or when a window starts showing a different buffer.
  (add-hook 'window-selection-change-functions
            #'my/pi-coding-agent-auto-input--schedule)
  (add-hook 'window-buffer-change-functions
            #'my/pi-coding-agent-auto-input--schedule))

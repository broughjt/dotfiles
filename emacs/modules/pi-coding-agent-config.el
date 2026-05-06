;;; -*- lexical-binding: t; -*-

(defvar pi-coding-agent--chat-buffer)
(defvar pi-coding-agent--input-buffer)
(defvar my/pi-coding-agent-auto-input--pending nil)
(defvar my/pi-coding-agent-auto-input--busy nil)

(declare-function pi-coding-agent--input-height-for-window "pi-coding-agent-ui")
(declare-function pi-coding-agent--window-can-split-for-input-p "pi-coding-agent-ui")

(defun my/pi-coding-agent-auto-input--chat-for-buffer (buffer)
  "Return BUFFER's linked pi chat buffer, or nil."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (cond
       ((derived-mode-p 'pi-coding-agent-chat-mode)
        buffer)
       ((and (derived-mode-p 'pi-coding-agent-input-mode)
             (bound-and-true-p pi-coding-agent--chat-buffer)
             (buffer-live-p pi-coding-agent--chat-buffer))
        pi-coding-agent--chat-buffer)))))

(defun my/pi-coding-agent-auto-input--last-chat (&optional frame)
  "Return FRAME's last selected pi chat buffer."
  (frame-parameter frame 'my/pi-coding-agent-auto-input--last-chat))

(defun my/pi-coding-agent-auto-input--set-last-chat (chat &optional frame)
  "Remember CHAT as FRAME's last selected pi chat buffer."
  (set-frame-parameter frame 'my/pi-coding-agent-auto-input--last-chat chat))

(defun my/pi-coding-agent-auto-input--hide (chat)
  "Delete CHAT's pi input windows in the selected frame."
  (when (buffer-live-p chat)
    (let ((input (buffer-local-value 'pi-coding-agent--input-buffer chat)))
      (when (buffer-live-p input)
        (dolist (window (get-buffer-window-list input nil))
          (ignore-errors (delete-window window)))))))

(defun my/pi-coding-agent-auto-input--show (chat)
  "Show CHAT's pi input buffer below its selected-frame chat window."
  (let ((input (buffer-local-value 'pi-coding-agent--input-buffer chat))
        (chat-window (get-buffer-window chat nil)))
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

(defun my/pi-coding-agent-auto-input--sync ()
  "Synchronize pi input-window visibility with the selected window."
  (setq my/pi-coding-agent-auto-input--pending nil)
  (unless (or my/pi-coding-agent-auto-input--busy
              (minibufferp (window-buffer (selected-window))))
    (let ((my/pi-coding-agent-auto-input--busy t))
      (condition-case err
          (let* ((frame (selected-frame))
                 (buffer (window-buffer (selected-window)))
                 (chat (my/pi-coding-agent-auto-input--chat-for-buffer buffer))
                 (last-chat (my/pi-coding-agent-auto-input--last-chat frame)))
            (cond
             (chat
              (unless (eq chat last-chat)
                (my/pi-coding-agent-auto-input--hide last-chat))
              (my/pi-coding-agent-auto-input--set-last-chat chat frame)
              (with-current-buffer buffer
                (when (derived-mode-p 'pi-coding-agent-chat-mode)
                  (my/pi-coding-agent-auto-input--show chat))))
             (t
              (my/pi-coding-agent-auto-input--hide last-chat)
              (my/pi-coding-agent-auto-input--set-last-chat nil frame))))
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
  :config
  ;; Keep pi's prompt buffer paired with the selected chat buffer, but hide
  ;; just the prompt window when leaving the pi session.  These hooks are more
  ;; specific than `post-command-hook': they fire when window selection changes
  ;; or when a window starts showing a different buffer.
  (add-hook 'window-selection-change-functions
            #'my/pi-coding-agent-auto-input--schedule)
  (add-hook 'window-buffer-change-functions
            #'my/pi-coding-agent-auto-input--schedule))

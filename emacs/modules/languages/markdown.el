;;; -*- lexical-binding: t; -*-

(defconst jackson/markdown-live-preview-bun-port 4173
  "Port for Bun-based markdown live preview.")

(defconst jackson/markdown-live-preview-status-buffer-name
  "*markdown-live-preview-browser*"
  "Buffer name for markdown live preview status.")

(defvar jackson/markdown-live-preview-bun-process nil
  "Background Bun process for markdown live preview.")

(defvar jackson/markdown-live-preview-bun-target-file nil
  "Current HTML file served by the Bun preview server.")

(defvar-local jackson/markdown-live-preview-opened-this-activation nil
  "Whether live preview browser has been opened for this mode activation.")

(defun jackson/markdown-live-preview-get-filename (&rest _)
  "Return a stable /tmp path for markdown live preview HTML."
  (let ((source (buffer-file-name)))
    (when source
      (let* ((base (file-name-base source))
             (hash (substring (md5 source) 0 10)))
        (expand-file-name
         (format "markdown-live-preview-%s-%s.html" base hash)
         "/tmp/")))))

(defun jackson/markdown-live-preview-url ()
  "Return the Bun live preview URL."
  (format "http://localhost:%d" jackson/markdown-live-preview-bun-port))

(defun jackson/markdown-live-preview-start-bun-server (file)
  "Start or repoint Bun preview server to FILE."
  (let* ((live (and jackson/markdown-live-preview-bun-process
                    (process-live-p jackson/markdown-live-preview-bun-process)))
         (same-target (and live
                           (equal jackson/markdown-live-preview-bun-target-file
                                  file))))
    (when (and live (not same-target))
      (kill-process jackson/markdown-live-preview-bun-process)
      (setq jackson/markdown-live-preview-bun-process nil))
    (unless same-target
      (let* ((buffer (get-buffer-create
                      jackson/markdown-live-preview-status-buffer-name))
             (script
              (format
               (concat
                "import page from %S;"
                "Bun.serve({port:%d,routes:{\"/\":page},development:true});")
               file
               jackson/markdown-live-preview-bun-port))
             (process
              (start-process
               "markdown-live-preview-bun"
               buffer
               "nix"
               "run"
               "nixpkgs#bun"
               "--"
               "--eval"
               script)))
        (set-process-query-on-exit-flag process nil)
        (setq jackson/markdown-live-preview-bun-process process)
        (setq jackson/markdown-live-preview-bun-target-file file)))))

(defun jackson/markdown-live-preview-track-activation ()
  "Reset browser-open state only when live preview mode is disabled."
  (unless markdown-live-preview-mode
    (setq jackson/markdown-live-preview-opened-this-activation nil)))

(defun markdown-live-preview-mode-window-function (file)
  "Preview FILE in the external browser for live preview mode.
Return a buffer as required by `markdown-live-preview-window-function'."
  (jackson/markdown-live-preview-start-bun-server file)
  (unless jackson/markdown-live-preview-opened-this-activation
    (browse-url (jackson/markdown-live-preview-url))
    (setq jackson/markdown-live-preview-opened-this-activation t))
  (with-current-buffer
      (get-buffer-create jackson/markdown-live-preview-status-buffer-name)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert
       (format "Bun markdown live preview:\nsource: %s\nurl: %s\n"
               file
               (jackson/markdown-live-preview-url)))
      (special-mode))
    (current-buffer)))

(use-package markdown-mode
  :mode
  (("README\\.md\\'" . gfm-mode)
   ("\\.md\\'" . markdown-mode))
  :init
  (setq markdown-command '("pulldown-cmark")
        markdown-live-preview-window-function
        #'markdown-live-preview-mode-window-function
        markdown-enable-wiki-links t
        markdown-fontify-code-blocks-natively t)
  :config
  (advice-remove 'markdown-live-preview-get-filename
                 #'jackson/markdown-live-preview-get-filename)
  (advice-add 'markdown-live-preview-get-filename
              :override
              #'jackson/markdown-live-preview-get-filename)
  (add-hook 'markdown-live-preview-mode-hook
            #'jackson/markdown-live-preview-track-activation))

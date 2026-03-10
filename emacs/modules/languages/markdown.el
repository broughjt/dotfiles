;;; -*- lexical-binding: t; -*-

(defun markdown-live-preview-mode-window-function (file)
  "Preview FILE in the external browser for live preview mode.
Return a buffer as required by `markdown-live-preview-window-function'."
  (browse-url-of-file file)
  (with-current-buffer (get-buffer-create "*markdown-live-preview-browser*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert (format "External markdown live preview: %s\n" file))
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
        markdown-fontify-code-blocks-natively t))

;; -*- lexical-binding: t; -*-

(defvar grip-real-time-refresh)
(defvar grip--preview-file)
(declare-function grip-start-process "grip-mode")

(use-package markdown-mode
  :mode
  (("README\\.md\\'" . gfm-mode)
   ("\\.md\\'" . markdown-mode))
  :custom
  (markdown-enable-wiki-links t)
  (markdown-fontify-code-blocks-natively t))

(use-package grip-mode
  :custom
  ;; Prefer the local, GitHub-API-free backend supplied by Nix.
  (grip-command 'go-grip)
  ;; Keep Markdown previews updated before the buffer is saved.
  (grip-real-time-refresh t)
  :config
  ;; `grip-mode' implements real-time Markdown refresh by copying the current
  ;; buffer to BUFFER-FILE.temp.md and asking go-grip to serve that copy. The
  ;; upstream implementation creates that copy beside the source file, because
  ;; it derives the temp path with `(concat buffer-file-name ".temp.md")'. Keep
  ;; the same live-refresh behavior, but put those disposable preview files in
  ;; /tmp and start go-grip there; the go-grip/mdopen integration passes only
  ;; the temp file's basename to the subprocess.
  (defun grip--preview-md ()
    "Render and preview markdown with grip."
    (if grip-real-time-refresh
        (let ((default-directory "/tmp/"))
          (setq grip--preview-file
                (make-temp-file
                 (expand-file-name
                  (concat (file-name-nondirectory buffer-file-name) ".")
                  default-directory)
                 nil
                 ".md"))
          (copy-file buffer-file-name grip--preview-file "overwrite")
          (grip-start-process))
      (setq grip--preview-file buffer-file-name)
      (grip-start-process)))
  :bind (:map markdown-mode-command-map
              ("g" . grip-mode)))

(provide 'language-markdown)

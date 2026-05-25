;; -*- lexical-binding: t; -*-

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
  :bind (:map markdown-mode-command-map
              ("g" . grip-mode)))

(provide 'language-markdown)

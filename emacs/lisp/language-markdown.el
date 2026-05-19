;;; -*- lexical-binding: t; -*-

(use-package markdown-mode
  :mode
  (("README\\.md\\'" . gfm-mode)
   ("\\.md\\'" . markdown-mode))
  :custom
  (markdown-enable-wiki-links t)
  (markdown-fontify-code-blocks-natively t))

(provide 'language-markdown)

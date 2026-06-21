;;; -*- lexical-binding: t; -*-

(defvar eglot-server-programs)
(defvar weibian-directory)
(declare-function eglot-alternatives "eglot" (servers))
(declare-function eglot-inlay-hints-mode "eglot" (&optional arg))

(defun jackson/weibian-typst-disable-inlay-hints ()
  "Turn off Eglot inlay hints by default in Weibian Typst buffers."
  (when (and (derived-mode-p 'typst-ts-mode)
             (bound-and-true-p weibian-directory)
             buffer-file-name
             (file-in-directory-p
              (file-truename buffer-file-name)
              (file-truename (expand-file-name weibian-directory))))
    (eglot-inlay-hints-mode -1)))

(use-package typst-ts-mode
  :mode "\\.typ\\'"
  :hook
  ((typst-ts-mode . eglot-ensure))
  :custom
  (typst-ts-indent-offset 2)
  :config
  (with-eval-after-load 'eglot
    (add-hook 'eglot-managed-mode-hook
              #'jackson/weibian-typst-disable-inlay-hints)
    (add-to-list 'eglot-server-programs
                 `((typst-ts-mode) . ,(eglot-alternatives `("tinymist"))))))

(provide 'language-typst)

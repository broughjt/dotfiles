;;; -*- lexical-binding: t; -*-

(defvar eglot-server-programs)
(defvar treesit-simple-indent-rules)
(declare-function eglot-alternatives "eglot" (servers))
(declare-function eglot-inlay-hints-mode "eglot" (&optional arg))

(defconst jackson/typst-ts-lagda-raw-block-indent-rule
  '((node-is "raw_blck") column-0 0)
  "Tree-sitter indentation rule that keeps Typst raw blocks at column zero.")

(defun jackson/weibian-typst-buffer-p ()
  "Return non-nil when the current buffer belongs to a Weibian project."
  (and buffer-file-name
       (locate-dominating-file
        (file-name-directory buffer-file-name)
        "weibian.json")))

(defun jackson/weibian-lagda-typst-buffer-p ()
  "Return non-nil in literate Agda Typst buffers in Weibian projects."
  (and (jackson/weibian-typst-buffer-p)
       (string-match-p "\\.lagda\\.typ\\'" buffer-file-name)))

(defun jackson/typst-ts-flush-raw-blocks-in-lagda ()
  "Keep raw/code blocks flush-left in Weibian `.lagda.typ' buffers.

Agda's layout checker sees the contents of every Typst raw block in a
`.lagda.typ' file.  Top-level declarations from different blocks must start
in the same column, so code blocks should stay at column zero even when they
occur inside indented `#subnode' prose.  This prepends a buffer-local
`raw_blck' indentation rule while leaving prose, math, lists, and theorem
bodies on the normal `typst-ts-indent-offset' path."
  (when (jackson/weibian-lagda-typst-buffer-p)
    (setq-local
     treesit-simple-indent-rules
     (mapcar
      (lambda (entry)
        (if (eq (car entry) 'typst)
            (let ((rules (cdr entry)))
              (if (member jackson/typst-ts-lagda-raw-block-indent-rule rules)
                  entry
                (cons 'typst
                      (cons jackson/typst-ts-lagda-raw-block-indent-rule
                            rules))))
          entry))
      treesit-simple-indent-rules))))

(defun jackson/weibian-typst-disable-inlay-hints ()
  "Turn off Eglot inlay hints by default in Weibian Typst buffers."
  (when (and (derived-mode-p 'typst-ts-mode)
             (jackson/weibian-typst-buffer-p))
    (eglot-inlay-hints-mode -1)))

(use-package typst-ts-mode
  :mode "\\.typ\\'"
  :hook
  ;; TODO: Disable tinymist for now
  ;; ((typst-ts-mode . eglot-ensure)
  ;;  (typst-ts-mode . jackson/typst-ts-flush-raw-blocks-in-lagda))
  ((typst-ts-mode . jackson/typst-ts-flush-raw-blocks-in-lagda))
  :custom
  (typst-ts-indent-offset 2)
  ;; TODO: Disable tinymist for now
  ;; :config
  ;; (with-eval-after-load 'eglot
  ;;   (add-hook 'eglot-managed-mode-hook
  ;;             #'jackson/weibian-typst-disable-inlay-hints)
  ;;   (add-to-list 'eglot-server-programs
  ;;                `((typst-ts-mode) . ,(eglot-alternatives `("tinymist")))))
  )

(provide 'language-typst)

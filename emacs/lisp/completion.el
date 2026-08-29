;;; -*- lexical-binding: t; -*-

(defvar ispell-alternate-dictionary)
(defvar ispell-complete-word-dict)

(declare-function marginalia-mode "marginalia" (&optional arg))
(declare-function vertico-mode "vertico" (&optional arg))
(declare-function vertico-directory-tidy "vertico-directory" ())
(declare-function global-corfu-mode "corfu" (&optional arg))
(declare-function corfu-popupinfo-mode "corfu-popupinfo" (&optional arg))
(declare-function cape-wrap-buster "cape" (fn &rest args))
(declare-function cape-dabbrev "cape" ())
(declare-function cape-file "cape" ())
(declare-function tempel-expand "tempel" (&rest args))

(use-package vertico
  :config
  ;; `vertico-directory-tidy' lives in the optional vertico-directory module.
  ;; Load it explicitly before installing the hook; otherwise, with package.el
  ;; autoload activation disabled, the hook can point at an unloaded function.
  (require 'vertico-directory)
  (add-hook 'rfn-eshadow-update-overlay-hook #'vertico-directory-tidy)
  (vertico-mode))

(use-package marginalia
  :config
  (marginalia-mode))

(use-package consult
  ;; Nix's `emacsWithPackages' puts packages on `load-path' but does not load
  ;; package.el autoload files.  Loading Consult eagerly keeps non-bound
  ;; commands such as `consult-theme' visible in `M-x' from startup.
  :demand t
  :bind (("C-x b" . consult-buffer)
         ("C-x p b" . consult-project-buffer)
         ("M-g l" . consult-line)
         ("M-s f" . consult-fd)
         ("M-s g" . consult-ripgrep)))

(use-package consult-imenu
  ;; Recent Consult versions split Imenu commands into `consult-imenu.el'.  A
  ;; `use-package consult' binding would autoload from the wrong file and fail
  ;; with "failed to define function consult-imenu".
  :demand t
  :bind (("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides
   '((file (styles basic partial-completion))
     (eglot (styles orderless))
     (eglot-capf (styles orderless))
     ;; Racket Mode registers these categories with `basic' defaults. Keep
     ;; them prefix-based; Racket's CAPF intentionally starts after 2 chars.
     (racket-identifier (styles basic))
     (racket-module (styles basic)))))

(use-package which-key
  :config (which-key-mode 1))

(setq tab-always-indent 'complete)

(let ((dict (getenv "EMACS_ISPELL_COMPLETE_WORD_DICT")))
  (when (and dict (> (length dict) 0))
    (if (file-readable-p dict)
        (setq ispell-complete-word-dict dict
              ispell-alternate-dictionary dict)
      (message "EMACS_ISPELL_COMPLETE_WORD_DICT is not readable: %s" dict))))

;; (read-extended-command-predicate #'command-completion-default-include-p)

(use-package corfu
  :custom
  (corfu-cycle t)
  (corfu-auto t)
  ;; Corfu's default is 3, while Racket Mode's CAPF starts offering candidates
  ;; after 2 chars. Use the lower threshold so Racket XP completions appear as
  ;; soon as the backend can provide them.
  (corfu-auto-prefix 2)
  ;; (corfu-quit-no-match t)
  ;; (corfu-quit-at-boundary t)
  :config
  (require 'corfu-popupinfo)
  ;; (setq corfu-popupinfo-delay '(1.25 . 0.5))
  (corfu-popupinfo-mode 1) ; shows documentation next to completions
  (global-corfu-mode))

(use-package cape
  :demand t
  :config
  (advice-add 'eglot-completion-at-point :around #'cape-wrap-buster)
  (add-hook 'completion-at-point-functions #'cape-dabbrev 20)
  (add-hook 'completion-at-point-functions #'cape-file 20))

(defvar jackson/tempel-typst-templates
  '((sa "```agda" n p n "```"))
  "Tempel templates available in `typst-ts-mode'.")

(defun jackson/tempel-setup-capf ()
  "Add `tempel-expand' to the buffer-local capf list."
  ;; `tempel-expand' is not autoloaded in the Nix-built Emacs package set, but
  ;; Corfu will call it later through `completion-at-point-functions'. Load
  ;; Tempel before installing the CAPF to avoid delayed void-function errors.
  (require 'tempel)
  (add-hook 'completion-at-point-functions #'tempel-expand nil t))

(defun jackson/tempel-setup-typst ()
  "Make `jackson/tempel-typst-templates' visible in this buffer."
  (require 'tempel)
  (add-hook 'tempel-template-sources
            'jackson/tempel-typst-templates nil 'local))

(use-package tempel
  :bind (("M-+" . tempel-complete)
         ("M-*" . tempel-insert))
  :hook ((prog-mode . jackson/tempel-setup-capf)
         (text-mode . jackson/tempel-setup-capf)
         (typst-ts-mode . jackson/tempel-setup-typst)))

(use-package jinx
  :hook (emacs-startup . global-jinx-mode)
  :custom
  (global-jinx-modes '((not markdown-mode) text-mode prog-mode conf-mode))
  :bind (("M-$" . jinx-correct)
         ("C-M-$" . jinx-languages)))

(provide 'completion)

(use-package vertico
  :init
  (vertico-mode)
  :hook ((rfn-eshadow-update-overlay . #'vertico-directory-tidy)))

(use-package marginalia
  :init
  (marginalia-mode))

(use-package consult
  :bind (("C-x b" . consult-buffer)
         ("C-x p b" . consult-project-buffer)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ("M-s d" . consult-find)
         ("M-s g" . consult-ripgrep)))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package which-key
  :config (which-key-mode 1))

(use-package company
  :custom
  (company-idle-delay 0.1)
  :bind
  (:map company-active-map
        ("C-n" . company-select-next)
        ("C-p" . company-select-previous))
  :init
  (global-company-mode))

(use-package yasnippet
  :config
  (yas-global-mode 1)
  (yas-define-snippets
   'typst-ts-mode
   '(("sa" "\\`\\`\\`agda\n$0\n\\`\\`\\`"))))

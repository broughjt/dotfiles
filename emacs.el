(setq package-enable-at-startup nil)
(setq use-package-ensure-function 'ignore)
(setq package-archives nil)

(setq use-package-always-ensure t)
(eval-when-compile (require 'use-package))
;; Required for ~:bind~ to work later
(require 'bind-key)

(when (fboundp 'menu-bar-mode) (menu-bar-mode 0))
(when (fboundp 'tool-bar-mode) (tool-bar-mode 0))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode 0))
(when (eq system-type 'gnu/linux)
  (add-to-list 'default-frame-alist '(undecorated . t))
  (add-to-list 'default-frame-alist '(fullscreen . maximized)))
(add-to-list 'default-frame-alist `(font . ,(if (eq system-type 'gnu/linux) "JetBrainsMono 12" "JetBrains Mono 14")))
(setq visible-bell t)
(setq display-line-numbers-type 'visual)
(global-display-line-numbers-mode)

(setq local-directory (expand-file-name "~/.local/data/emacs/"))
(setq backup-directory (concat local-directory "backups/"))
(setq auto-save-directory (concat local-directory "auto-saves/"))
(setq backup-directory-alist '(("*" . ,backup-directory)))
(setq backup-inhibited t)
(setq auto-save-file-name-transforms `((".*" ,auto-save-directory t)))
(setq auto-save-list-file-prefix auto-save-directory)
(setq auto-save-default nil)
(setq create-lockfiles nil)
(setq vc-make-backup-files t)
(setq custom-file (concat user-emacs-directory "custom.el"))

(setq-default indent-tabs-mode nil)

(use-package evil
 :init
 (setq evil-want-keybinding nil)
 :custom
 (evil-undo-system 'undo-redo)
 :config
 (evil-mode 1))

(use-package evil-collection
 :after evil
 :custom (evil-want-keybinding nil)
 :init
 (evil-collection-init))

(setq org-src-preserve-indentation nil
      org-edit-src-content-indentation 0
      org-confirm-babel-evaluate nil
      org-babel-load-languages
        '((emacs-lisp . t)
          (shell . t)
          (python . t))
      org-latex-compiler "lualatex"
      org-latex-create-formula-image-program 'dvisvgm
      org-preview-latex-image-directory temporary-file-directory
      org-latex-packages-alist '(("" "bussproofs" t))
      org-startup-with-latex-preview t
      org-startup-with-inline-images t
      org-agenda-span 14)
(with-eval-after-load 'org
  (plist-put org-format-latex-options :background "Transparent"))
(add-hook 'org-mode-hook 'turn-on-auto-fill)

(use-package org-ql)
(use-package org-roam-ql)

(use-package org-fragtog
  :hook (org-mode . org-fragtog-mode))

(use-package org-roam
  :custom
  (org-roam-v2-ack t)
  (org-directory "~/share")
  (org-roam-directory "~/share/notes")
  (org-roam-dailies-directory "journals/")
  (org-cite-global-bibliography '("~/share/notes/citations.bib"))
  (org-roam-capture-templates
   '(("d" "default" plain
      "%?" :target
      (file+head "pages/${slug}.org" "#+title: ${title}\n")
      :unnarrowed t)))
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert))
  :config
  (require 'oc-basic)
  (org-roam-setup))

(use-package org-roam-ui
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

(use-package org-gtd
  :after
  org
  :init
  (setq org-gtd-update-ack "3.0.0")
  :custom
  (org-gtd-directory "~/share/org/gtd/")
  (org-edna-use-inheritance t)
  :config
  (org-edna-mode)
  (org-gtd-mode)
  :bind
  (("C-c d c" . org-gtd-capture)
   ("C-c d d" . (lambda (&optional GOTO)
                  (interactive)
                  (org-gtd-capture GOTO "i")))
   :map org-gtd-clarify-map
   ("C-c c" . org-gtd-organize)))

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
  (yas-reload-all)
  (add-hook 'prog-mode-hook 'yas-minor-mode)
  (add-hook 'text-mode-hook 'yas-minor-mode))

(use-package dap-mode
  :after lsp-mode
  :commands dap-debug
  :hook ((python-mode . dap-ui-mode)
	 (python-mode . dap-mode))
  :custom
  (dap-python-debugger 'debugpy)
  :config
  (eval-when-compile
    (require 'cl))
  (require 'dap-python)
  (require 'dap-lldb))

(use-package standard-themes)

(use-package modus-themes)

(use-package ef-themes 
  :init
  (load-theme 'ef-light t))

(use-package racket-mode)

(use-package rust-mode
  :hook
  ((rust-mode . eglot-ensure)
   (rust-mode . flycheck-mode))
  :config
  (setq-default eglot-workspace-configuration
                '(:rust-analyzer (:check (:command "clippy")))))

(use-package proof-general)

(use-package lean4-mode
  :mode "\\.lean\\'")

(use-package haskell-mode
  :hook
  ((haskell-mode . eglot-ensure)))

(use-package magit)

(use-package nix-mode
  :mode "\\.nix\\'")

(use-package envrc
  :config
  (envrc-global-mode))

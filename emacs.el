(setq package-enable-at-startup nil)
(setq use-package-ensure-function 'ignore)
(setq package-archives nil)

(require 'bind-key)

(menu-bar-mode 0)
(tool-bar-mode 0)
(scroll-bar-mode 0)

;; (add-to-list 'default-frame-alist '(font . "JetBrains Mono 12"))

(setq visible-bell t)

(setq display-line-numbers-type 'visual)
(global-display-line-numbers-mode)

(setq local-directory (expand-file-name "~/.local/data/emacs/"))
(setq backup-directory (concat local-directory "backups/"))
(setq auto-save-directory (concat local-directory "auto-saves/"))

(setq backup-directory-alist `((".*" . ,backup-directory)))
(setq auto-save-file-name-transforms `((".*" ,auto-save-directory t)))

(setq create-lockfiles nil)

(setq custom-file (concat local-directory "custom.el"))
(load custom-file)

(setq-default indent-tabs-mode nil)

(unless (eq system-type 'windows-nt)
  (use-package exec-path-from-shell
    :config
    (dolist (var '("SSH_AUTH_SOCK" "SSH_AGENT_PID" "GPG_AGENT_INFO" "GNUPGHOME" "LANG" "LC_CTYPE" "NIX_SSL_CERT_FILE" "NIX_PATH"))
      (add-to-list 'exec-path-from-shell-variables var))
    (exec-path-from-shell-initialize)))

;; (setq epg-pinentry-mode 'loopback)
;; (setenv "GNUPGHOME" "/home/jackson/.local/share/gnupg")

(use-package evil
 :init
 (setq evil-want-keybinding nil)
 :custom
 (evil-undo-system 'undo-redo)
 :config
 (evil-mode 1))

(use-package evil-collection
 :after evil
 :init
 (evil-collection-init))

(setq org-src-preserve-indentation nil
      org-edit-src-content-indentation 0)

(setq
 org-confirm-babel-evaluate nil
 org-babel-load-languages
 '((emacs-lisp . t)
   (shell . t)
   (python . t)))

(setq
 org-latex-compiler "lualatex"
 org-latex-create-formula-image-program 'dvisvgm
 org-preview-latex-image-directory temporary-file-directory
 org-latex-packages-alist '(("" "bussproofs" t) ("" "simplebnf" t))
 org-startup-with-latex-preview t
 org-startup-with-inline-images t)
(with-eval-after-load 'org
  (plist-put org-format-latex-options :background "Transparent"))

(add-hook 'org-mode-hook 'turn-on-auto-fill)

(setq org-directory "~/repositories/gtd/")
(setq inbox-file (concat org-directory "inbox.org"))
(setq tasks-file (concat org-directory "tasks.org"))
(setq suspended-file (concat org-directory "suspended.org"))
(setq calendar-file (concat org-directory "calendar.org"))
(setq archive-file (concat org-directory "archive.org"))

(setq org-agenda-files (list tasks-file calendar-file suspended-file))
(setq org-refile-targets
      '((nil :maxlevel . 9) (org-agenda-files :maxlevel . 9)))
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-use-outline-path 'file)
(setq org-archive-location (concat archive-file "::"))

(setq org-tag-alist '(("next" . ?n) ("wait" . ?w)))

(setq org-capture-templates
      '(("d" "default" entry (file inbox-file)
         "* %?\n%U\n")))

(bind-key "C-c d d"
          (lambda (&optional GOTO)
            (interactive)
            (org-capture GOTO "d")))
(bind-key "C-c r t"
          (lambda ()
            (interactive)
            (org-refile nil nil (list nil tasks-file nil nil))))

(setq org-todo-keywords '((sequence "TODO(!)" "DONE(!)")))
(setq org-log-into-drawer t)

(with-eval-after-load 'org
  (add-to-list 'org-modules 'org-habit t))

(setq org-cite-global-bibliography '("~/share/notes/citations.bib"))

(use-package org-roam
  :custom
  (org-roam-directory "~/share/notes")
  :bind
  (("C-c n f" . org-roam-node-find)
   ("C-c n i" . org-roam-node-insert))
  :config
  (org-roam-db-autosync-mode))

(use-package org-roam-ui
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

(use-package git-auto-commit-mode)

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
  (load-theme 'ef-dark t))

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

(use-package emms
  :config
  (require 'emms-setup)
  (emms-all)
  (setq emms-source-file-default-directory (expand-file-name "~/share/music/"))
  (setq emms-player-mpd-server-name "localhost")
  (setq emms-player-mpd-server-port "6600")
  (setq emms-player-mpd-music-directory "~/share/music")
  (add-to-list 'emms-info-functions 'emms-info-mpd)
  (add-to-list 'emms-player-list 'emms-player-mpd)
  (emms-player-mpd-connect)
  (add-hook 'emms-playlist-cleared-hook 'emms-player-mpd-clear))

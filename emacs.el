(setq package-enable-at-startup nil)
(setq use-package-ensure-function 'ignore)
(setq package-archives nil)

(require 'bind-key)

(menu-bar-mode 0)
(tool-bar-mode 0)
(scroll-bar-mode 0)

(set-face-attribute 'default nil :family "JuliaMono" :height 100)

(setq visible-bell t)

(setq display-line-numbers-type 'visual)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)

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

(setq-default fill-column 80)
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)

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

;; (setq
;;  org-latex-create-formula-image-program 'dvisvgm
;;  org-preview-latex-image-directory temporary-file-directory
;;  org-latex-packages-alist '(("" "bussproofs" t) ("" "simplebnf" t) ("" "tikz-cd" t) ("" "notes" t))
;;  org-startup-with-latex-preview t
;;  org-startup-with-inline-images t)
;; (with-eval-after-load 'org
;;   (plist-put org-format-latex-options :background "Transparent")
;;   ;; TODO: Works for now?
;;   (plist-put org-format-latex-options :scale 0.5))
;; (use-package org)

;; (use-package org-latex-preview
;;   :config
;;   (add-hook 'org-mode-hook 'org-latex-preview-auto-mode)

;;   (setq org-latex-preview-live t)
;;   (setq org-latex-preview-live-debounce 0.25))
  
(setenv "TEXINPUTS" (concat (expand-file-name "~/repositories/notes/tex/") ":" (getenv "TEXINPUTS")))

(add-hook 'org-mode-hook 'turn-on-auto-fill)

(setq org-directory "~/repositories/gtd/")
(setq inbox-file (concat org-directory "inbox.org"))
(setq tasks-file (concat org-directory "tasks.org"))
(setq suspended-directory (concat org-directory "suspended/"))
(setq write-file (concat suspended-directory "write.org"))
(setq read-file (concat suspended-directory "read.org"))
(setq other-file (concat suspended-directory "other.org"))
(setq calendar-file (concat org-directory "calendar.org"))
(setq archive-file (concat org-directory "archive.org"))

(setq org-agenda-files (list tasks-file calendar-file
                             ;; TODO: These probably are a seperate thing
                             write-file read-file other-file))
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
(bind-key "C-c a" 'org-agenda)

(setq org-todo-keywords '((sequence "TODO(!)" "DONE(!)")))
(setq org-log-into-drawer t)
(setq org-log-done 'time)

(with-eval-after-load 'org
  (add-to-list 'org-modules 'org-habit t))

(with-eval-after-load 'org
  (require 'oc-basic))
(setq org-cite-global-bibliography '("~/repositories/notes/citations.bib"))

(use-package org-roam
  :custom
  (org-roam-directory "~/repositories/notes")
  (org-roam-file-exclude-regexp nil)
  :bind
  (("C-c n f" . org-roam-node-find)
   ("C-c n i" . org-roam-node-insert))
  :config
  ;; TODO: Buggy
  ;; (org-roam-db-autosync-mode)
  )

(use-package org-roam-ui
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

(use-package git-auto-commit-mode)

(use-package auctex
  :init
  (setq TeX-electric-sub-and-superscript t))

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

;; (use-package dap-mode
;;   :after lsp-mode
;;   :commands dap-debug
;;   :hook ((python-mode . dap-ui-mode)
;;          (python-mode . dap-mode))
;;   :custom
;;   (dap-python-debugger 'debugpy)
;;   :config
;;   (eval-when-compile
;;     (require 'cl))
;;   (require 'dap-python)
;;   (require 'dap-lldb))

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

(use-package lean4-mode
  :mode "\\.lean\\'")

(use-package haskell-mode
  :hook
  ((haskell-mode . eglot-ensure)))

(setq verilog-indent-level 4)
(setq verilog-case-indent 4)
(setq verilog-cexp-indent 4)
(setq verilog-indent-level-behavioral 4)
(setq verilog-indent-level-declaration 4)
(setq verilog-indent-level-module 4)
(setq verilog-indent-level-module 4)
(setq verilog-align-ifelse t)
(setq verilog-auto-delete-trailing-whitespace t)
(setq verilog-auto-newline nil)
(setq verilog-auto-lineup nil)
(setq verilog-highlight-grouping-keywords t)
(setq verilog-highlight-modules t)
;; If users feel compelled to add comments signaling the end of blocks
;; then you should change your language syntax
(setq verilog-auto-endcomments nil)

(use-package magit)

(use-package nix-mode
  :mode "\\.nix\\'")

(use-package envrc
  :config
  (envrc-global-mode))

(use-package inheritenv
  :demand t)

(load-file (let ((coding-system-for-read 'utf-8))
             (shell-command-to-string "agda-mode locate")))

;; (use-package emms
;;   :config
;;   (require 'emms-setup)
;;   (emms-all)
;;   (setq emms-source-file-default-directory (expand-file-name "~/share/music/"))
;;   (setq emms-player-mpd-server-name "localhost")
;;   (setq emms-player-mpd-server-port "6600")
;;   (setq emms-player-mpd-music-directory "~/share/music")
;;   (add-to-list 'emms-info-functions 'emms-info-mpd)
;;   (add-to-list 'emms-player-list 'emms-player-mpd)
;;   (emms-player-mpd-connect)
;;   (add-hook 'emms-playlist-cleared-hook 'emms-player-mpd-clear))

(setq js-indent-level 2)
(add-to-list 'auto-mode-alist '("\\.js\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.mjs\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.cjs\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.mts\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.jsx\\'" . tsx-ts-mode))
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
(add-to-list 'auto-mode-alist '("\\.json\\'" . json-ts-mode))
(add-hook 'typescript-ts-mode-hook 'eglot-ensure)
(add-hook 'tsx-ts-mode-hook 'eglot-ensure)

(use-package gptel
  :init
  (defun jackson/gopass-show (key)
    "Call `gopass show KEY` and return its output as a string."
    (with-temp-buffer
      (let ((exit-code (call-process "gopass" nil t nil "show" key)))
        (if (= exit-code 0)
            (string-trim (buffer-string))
          (error "gopass show failed with exit code %d and message: %s" exit-code (buffer-string))))))
  (setq gptel-api-key (lambda () (jackson/gopass-show "openai-api-key1")))
  (setq gptel-default-mode 'org-mode))

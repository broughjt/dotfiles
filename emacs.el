;; TODO:
;; Holy cow I need a jumplist so bad
;; kakoune/helix
;;   navigation mode, maybe syntactically with treesitter
;; treesitter
;; <space> leader
;; dired
;; Alacritty has no scrollbar, and fish doesn't have backwards work kill with C-backspace, need a terminal in emacs
;;   Ideally, have a little popup window like vscode
;; buffer and window management in general
;; Highlight line with a different color if you're at the center of the buffer, I press zz all the time unnessarily
;;
;; debuggers

(setq package-enable-at-startup nil)
(setq use-package-ensure-function 'ignore)
(setq package-archives nil)

(setq use-package-always-ensure t)
(eval-when-compile (require 'use-package))

(when (fboundp 'menu-bar-mode) (menu-bar-mode 0))
(when (fboundp 'tool-bar-mode) (tool-bar-mode 0))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode 0))
(add-to-list 'default-frame-alist '(font . "JetBrainsMono 12"))
(setq visible-bell t)
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode)

;; TODO: Hack
;; https://github.com/jwiegley/use-package/issues/436
(require 'bind-key)

;; TODO: Actually understand these from long ago and hopefully get rid of most of it
;; TODO: Make path implicit
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
;; TODO: Ideally just don't have one
(setq custom-file (concat user-emacs-directory "custom.el"))

(use-package evil
  :custom
  (evil-want-keybinding nil)
  (evil-undo-system 'undo-redo)
  :config
  (evil-mode 1))

(use-package vertico
  :init
  (vertico-mode))

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

(use-package evil-collection
  :after evil
  :init
  (evil-collection-init))

(use-package which-key
  :config (which-key-mode 1))

(use-package company
  :custom
  (company-idle-delay 0.1)
  :bind
  (:map company-active-map
	("C-n" . company-select-next)
	("C-p" . company-select-previous)))

(use-package nix-mode
  :mode "\\.nix\\'")

(use-package envrc
  :config
  (envrc-global-mode))

(use-package racket-mode)

(use-package rustic)

(use-package lsp-mode
  :commands lsp
  :custom
  (lsp-rust-analyzer-cargo-watch-command "clippy")
  (lsp-eldoc-render-all t)
  (lsp-idle-delay 0.6)
  (lsp-rust-analyzer-server-display-inlay-hints t)
  :config
  (add-hook 'lsp-mode-hook 'lsp-ui-mode))

(use-package lsp-ui
  :commands lsp-ui-mode
  :custom
  (lsp-ui-peek-always-show t)
  (lsp-ui-sideline-show-hover t)
  (lsp-ui-doc-enable nil))

(use-package yasnippet
  :config
  (yas-reload-all)
  (add-hook 'prog-mode-hook 'yas-minor-mode)
  (add-hook 'text-mode-hook 'yas-minor-mode))

(use-package magit)

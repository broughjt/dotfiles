(setq package-enable-at-startup nil)
(setq use-package-ensure-function 'ignore)
(setq package-archives nil)

(setq use-package-always-ensure t)
(eval-when-compile (require 'use-package))

;; TODO: Actually understand these from long ago and hopefully get rid of most of it
;; TODO: Make path implicit
(setq local-directory (expand-file-name "~/home/local/data/emacs/"))
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

(add-to-list 'default-frame-alist
	     '(font . "JetBrainsMono 12"))
(setq visible-bell t)
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode)

(use-package evil
  :custom
  (evil-undo-system 'undo-redo)
  :config
  (evil-mode 1))

(use-package which-key
  :config (which-key-mode 1))

(use-package company
  :custom
  (company-idle-delay 0.1)
  :bind
  (:map company-active-map
	("C-n" . company-select-next)
	("C-p" . company-select-previous))
  :config
  (add-hook 'after-init-hook 'global-company-mode))

(use-package nix-mode
  :mode "\\.nix\\'")

;;; -*- lexical-binding: t; -*-

(defvar affe-find-command)

(declare-function marginalia-mode "marginalia" (&optional arg))
(declare-function affe-find "affe" (&optional dir initial))
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
  :bind (("C-x b" . consult-buffer)
         ("C-x p b" . consult-project-buffer)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ("M-g l" . consult-line)
         ;; ("M-s d" . consult-find)
         ("M-s g" . consult-ripgrep)))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(defvar rg-ignore-flags
  "-g \"!*.mp3\" -g \"!*.jpg\" -g \"!*.JPG\" -g \"!*.jpeg\" -g \"!*.png\" \
  -g \"!*.mkv\" -g \"!*.mp4\" -g \"!*.avi\" -g \"!*.zip\" -g \"!*.ddl\" \
  -g \"!*.ods\" -g \"!*.xlsx\" -g \"!*.m3u\" -g \"!*.url\" -g \"!*.aac\" \
  -g \"!*.mpc\" -g \"!*.sql\" -g \"!*.ydb\" -g \"!dist/\" \
  -g \"!.git/\" -g \"!git/*\" -g \"!node_modules/\" -g \"!*cache/\" \
  -g \"!.cache\" -g \"!vendor/\" \
  -g \"!.pki/\" -g \"!.local/share/*/\" \
  -g \"!local/cache/\" -g \"!local/config/\" -g \"!local/hacks/\" \
  -g \"!local/secrets/\" -g \"!local/share/*/\" -g \"!local/state/\" \
  -g \"!coverage\" -g \"!build/\" -g \"!var/\" -g \"!npm/\" \
  -g \"!Library/\" -g \"!.DS_Store\" -g \"!.stfolder\""
  "Exclusion flags for usage with ripgrep commands.")
(defvar fd-ignore-flags
  "-E \"*.mp3\" -E \"*.jpg\" -E \"*.JPG\" -E \"*.jpeg\" -E \"*.png\" \
  -E \"*.mkv\" -E \"*.mp4\" -E \"*.avi\" -E \"*.zip\" -E \"*.ddl\" \
  -E \"*.ods\" -E \"*.xlsx\" -E \"*.m3u\" -E \"*.url\" -E \"*.aac\" \
  -E \"*.mpc\" -E \"*.sql\" -E \"*.ydb\" -E \"dist\" \
  -E \".git\" -E \"git\" -E \"node_modules\" -E \"*cache\" \
  -E \".cache\" -E \"vendor\" \
  -E \".pki\" -E \".local/share/*\" \
  -E \"local/cache\" -E \"local/config\" -E \"local/hacks\" \
  -E \"local/secrets\" -E \"local/share/*\" -E \"local/state\" \
  -E \"coverage\" -E \"build\" -E \"var\" -E \"npm\" \
  -E \"Library\" -E \".DS_Store\" -E \".stfolder\""
  "Exclusion flags for usage with fd commands.")
(defvar rg-find-files-command
  (format "rg -L --ignore --hidden --files --color=never %s" rg-ignore-flags)
  "Command for finding files with ripgrep.")
(defvar fd-find-directories-command
  ;; Affe appends the search path(s) to the command.  `fd' needs an explicit
  ;; pattern before those paths; `.*' matches every directory.
  (format "fd -L -H --type directory --color=never %s .*" fd-ignore-flags)
  "Command for finding directories with fd.")

(defun affe-find-file (&optional dir)
  (interactive) ; default dir is cwd
  ;; These commands are our wrappers, not Affe autoloaded entry points, so make
  ;; sure the package is loaded before calling `affe-find'.
  (require 'affe)
  (let ((affe-find-command rg-find-files-command))
    (affe-find dir)))
(defun affe-find-directory (&optional dir)
  (interactive) ; default dir is cwd
  ;; These commands are our wrappers, not Affe autoloaded entry points, so make
  ;; sure the package is loaded before calling `affe-find'.
  (require 'affe)
  (let ((affe-find-command fd-find-directories-command))
    (affe-find dir)))
(defun affe-find-file-home ()
  (interactive)
  (affe-find-file (substitute-in-file-name "$HOME")))
(defun affe-find-directory-home ()
  (interactive)
  (affe-find-directory (substitute-in-file-name "$HOME")))

(use-package affe
  :bind (("M-s F"   . affe-find-file-home)
         ("M-s f" . affe-find-file)
         ("M-s d"   . affe-find-directory-home))
  :custom
  (affe-count 5000))

(use-package which-key
  :config (which-key-mode 1))

(setq tab-always-indent 'complete)
;; TODO: says it's undefined
;; (setq text-mode-ispell-word-completion nil)
;; (read-extended-command-predicate #'command-completion-default-include-p)

(use-package corfu
  :custom
  (corfu-cycle t)
  (corfu-auto t)
  ;; (corfu-quit-no-match t)
  ;; (corfu-quit-at-boundary t)
  :config
  (require 'corfu-popupinfo)
  ;; (setq corfu-popupinfo-delay '(1.25 . 0.5))
  (corfu-popupinfo-mode 1) ; shows documentation next to completions
  (global-corfu-mode))

(setq completion-category-overrides '((eglot (styles orderless))
                                      (eglot-capf (styles orderless))))
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
  :bind (("M-$" . jinx-correct)
         ("C-M-$" . jinx-languages)))

(provide 'completion)

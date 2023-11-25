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
(add-hook 'org-mode-hook 'turn-on-auto-fill)

(use-package org-modern
  :hook (org-mode . org-modern-mode))

(use-package org-fragtog
  :hook (org-mode . org-fragtog-mode))

(use-package org-roam
  :custom
  (org-roam-v2-ack t)
  ;; (org-directory "~/share/org")
  (org-roam-directory "~/share/notes")
  (org-roam-dailies-directory "journals/")
  (org-cite-global-bibliography '("~/share/notes/citations.bib"))
  (org-roam-capture-templates
   '(("d" "default" plain
      "%?" :target
      (file+head "pages/${slug}.org" "#+title: ${title}\n")
      :unnarrowed t)))
  ;; (org-agenda-files '("~/share/notes" "~/share/notes/daily" "~/share/org"))
  ;; (org-roam-dailies-capture-templates
   ;; '(("d" "default" entry
      ;; "* %?"
      ;; :target (file+head "%<%Y-%m-%d>.org"
                         ;; "#+title: %<%Y-%m-%d>\n\n"))))
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert)
         ;; ("C-c n t" . org-roam-dailies-capture-today)
         ;; ("C-c n a" . org-agenda)
         ;; ("C-c n b" . org-iswitchb)
         )
  :config
  (require 'oc-basic)
  (org-roam-setup))

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

(use-package nix-mode
  :mode "\\.nix\\'")

(use-package envrc
  :config
  (envrc-global-mode))

(use-package racket-mode)

(use-package rust-mode
  :hook
  ((rust-mode . eglot-ensure)
   (rust-mode . flymake-mode))
  :config
  (setq-default eglot-workspace-configuration
                '(:rust-analyzer (:check (:command "clippy")))))

(use-package proof-general)

(use-package magit)

;; (comment (use-package ryo-modal
;;   ;; :disabled
;;   :bind
;;   ("<escape>" . modal/normal-mode)
;;   :hook
;;   (after-init . modal/setup)
;;   (prog-mode . modal/normal-mode)
;;   :config  
;;   (defun modal/insert-mode ()
;;     "Return to insert mode."
;;     (interactive)
;;     (ryo-modal-mode 0))
;;   
;;   (defun modal/normal-mode ()
;;     "Enter normal mode."
;;     (interactive)
;;     (ryo-modal-mode 1))
;;   
;;   (defun modal/set-mark-at-point ()
;;     "Set the mark at the location of the point."
;;     (interactive)
;;     (set-mark (point)))
;;   
;;   (defun modal/set-mark-at-point-if-inactive ()
;;     "Set the mark at the location of the point if it isn't active."
;;     (interactive)
;;     (unless (use-region-p)
;;       (modal/set-mark-at-point)))
;;    
;;   ;; TODO: What's with rectangle-mark-mode
;;   (defun modal/deactivate-mark ()
;;     "Deactivate the mark.
;; 
;; Deactivate the mark unless mark-region-mode is active."
;;     (interactive)
;;     (unless rectangle-mark-mode (deactivate-mark)))
;; 
;;   ;;; Movement
;; 
;;   ;; TODO: bikeshed name, this is wrong
;;   (defun modal/select-word-end ()
;;     "Select preceding whitespaces and the word on the right of selection end."
;;     (interactive)
;;     (forward-word)
;;     (backward-char))
;; 
;;   (defun modal/backward-same-syntax (count)
;;     "Move backward COUNT times by same syntax blocks."
;;     (interactive "p")
;;     (forward-same-syntax (- count)))
;;  
;;   (defun modal/select-whole-line (count)
;;     "Expand selections to contain full lines."
;;     (interactive "p")
;;     (beginning-of-line)
;;     (modal/set-mark-at-point)
;;     (forward-line count))
;; 
;;   (defun modal/select-to (count character)
;;     "Select to (including) the COUNTth occurance of CHARACTER."
;;     (interactive "p\ncSelect to character: ")
;;     (let ((direction (if (>= count 0) 1 -1)))
;;       (forward-char direction)
;;       (unwind-protect
;;        (search-forward (char-to-string character) nil nil count))
;;       (point)))
;; 
;;   (defun modal/select-until (count character)
;;     "Select until (excluding) the COUNTth occurance of CHARACTER."
;;     (interactive "p\ncSelect until character: ")
;;     (let ((direction (if (>= count 0) 1 -1)))
;;       (forward-char direction)
;;       (unwind-protect
;;        (search-forward (char-to-string character) nil nil count)
;;        (backward-char direction))
;;       (point)))
;; 
;;   (defun modal/goto (count)
;;     "Go to the beginning of the buffer or the COUNTth line."
;;     (interactive "p")
;;     (goto-char (point-min))
;;     (when count (forward-line (1- count))))
;;        
;;   ;;; Changes
;;   
;;   (defun modal/kill (count)
;;     "Kill selected text or delete `count` characters."
;;     (interactive "p")
;;     (if (use-region-p)
;;         (kill-region (region-beginning) (region-end))
;;       (delete-char count t)))
;; 
;;   (defun modal/yank (count)
;;     "Yank COUNT times after the point."
;;     (interactive "p")
;;     (dotimes (_ count) (save-excursion (yank))))
;; 
;;   (defun modal/open-above (count)
;;     "Open COUNT lines above the cursor and go into insert mode."
;;     (interactive "p")
;;     (beginning-of-line)
;;     (dotimes (_ count)
;;       (newline)
;;       (forward-line -1)))
;; 
;;   (defun modal/open-below (count)
;;     "Open COUNT lines below the cursor and go into insert mode."
;;     (interactive "p")
;;     (end-of-line)
;;     (dotimes (_ count)
;;       (electric-newline-and-maybe-indent)))
;; 
;;   (defun modal/join ()
;;     "Join the next line to the current one."
;;     (interactive)
;;     (join-line 1))
;; 
;;   ;; Configuration
;; 
;;   (defun modal/setup ()
;;     "Set up keybindings for normal mode."
;;     (interactive)
;;     (global-subword-mode 1)
;;     (ryo-modal-major-mode-keys
;;      'prog-mode
;;      ("b" modal/backward-same-syntax :first '(modal/set-mark-at-point) :mc-all t)
;;      ("B" modal/backward-same-syntax :first '(modal/set-mark-at-point-if-inactive) :mc-all t)
;;      ("w" forward-same-syntax :first '(modal/set-mark-at-point) :mc-all t)
;;      ("W" forward-same-syntax :first '(modal/set-mark-at-point-if-inactive) :mc-all t))
;;     (ryo-modal-keys
;;      (:mc-all t)
;;      ("a" forward-char :exit t)
;;      ("A" move-end-of-line :exit t)
;;      ("b" backward-word :first '(modal/set-mark-at-point))
;;      ("B" backward-word :first '(modal/set-mark-at-point-if-inactive))
;;      ("c" modal/kill :exit t)
;;      ("C" ignore)
;;      ("d" modal/kill)
;;      ("D" ignore)
;;      ("e" ignore)
;;      ("E" ignore)
;;      ("f" modal/select-to :first '(modal/set-mark-at-point))
;;      ("F" modal/select-to :first '(modal/set-mark-at-point-if-inactive))
;;      ("g" (("g" modal/goto)
;;            ("h" beginning-of-line)
;;            ("i" back-to-indentation)
;;            ("j" end-of-buffer)
;;            ("k" beginning-of-buffer)
;;            ("l" end-of-line)) :first '(modal/deactivate-mark))
;;      ("G" (("g" modal/goto)
;;            ("i" back-to-indentation)
;;            ("h" beginning-of-line)
;;            ("j" end-of-buffer)
;;            ("k" beginning-of-buffer)
;;            ("l" end-of-line)) :first '(modal/set-mark-at-point-if-inactive))
;;      ("h" backward-char :first '(deactivate-mark))
;;      ("H" backward-char :first '(modal/set-mark-at-point-if-inactive))
;;      ("i" modal/insert-mode)
;;      ("I" back-to-indentation :exit t)
;;      ("j" next-line :first '(deactivate-mark))
;;      ("J" next-line :first '(modal/set-mark-at-point-if-inactive))
;;      ("M-j" modal/join)
;;      ("k" previous-line :first '(deactivate-mark))
;;      ("K" previous-line :first '(modal/set-mark-at-point-if-inactive))
;;      ("l" forward-char :first '(deactivate-mark))
;;      ("L" forward-char :first '(modal/set-mark-at-point-if-inactive))
;;      ("m" ignore)
;;      ("M" ignore)
;;      ("n" ignore)
;;      ("N" ignore)
;;      ;; TODO: These don't open the new line at the right indentation
;;      ("o" modal/open-below :exit t)
;;      ("O" modal/open-above :exit t)
;;      ("p" modal/yank)
;;      ("P" ignore)
;;      ("q" ignore)
;;      ("Q" ignore)
;;      ("r" ignore)
;;      ("R" ignore)
;;      ("s" ignore)
;;      ("S" ignore)
;;      ("t" modal/select-until :first '(modal/set-mark-at-point))
;;      ("T" modal/select-until :first '(modal/set-mark-at-point-if-inactive))
;;      ("u" undo)
;;      ("U" undo-redo)
;;      ("v" (("v" recenter)))
;;      ("V" ignore)
;;      ("w" forward-word :first '(modal/set-mark-at-point))
;;      ("W" forward-word :first '(modal/set-mark-at-point-if-inactive))
;;      ("x" modal/select-whole-line)
;;      ("X" ignore)
;;      ("y" kill-ring-save)
;;      ("Y" ignore)
;;      ("z" ignore)
;;      ("Z" ignore)
;;    
;;      ("0" "M-0")
;;      ("1" "M-1")
;;      ("2" "M-2")
;;      ("3" "M-3")
;;      ("4" "M-4")
;;      ("5" "M-5")
;;      ("6" "M-6")
;;      ("7" "M-7")
;;      ("8" "M-8")
;;      ("9" "M-9")
;;    
;;      ("~" ignore)
;;      ("`" ignore)
;;      ("!" ignore)
;;      ("@" ignore)
;;      ("#" ignore)
;;      ("$" ignore)
;;      ("%" ignore)
;;      ("^" ignore)
;;      ("&" ignore)
;;      ("*" ignore)
;;      ("(" ignore)
;;      (")" ignore)
;;      ("-" ignore)
;;      ("_" ignore)
;;      ("=" ignore)
;;      ("+" ignore)
;;      ("<backspace>" ignore)
;;      ("<del>" ignore)
;;      ("[" ignore)
;;      ("{" ignore)
;;      ("]" ignore)
;;      ("}" ignore)
;;      ("|" ignore)
;;      ("\\" ignore)
;;      (";" deactivate-mark)
;;      (":" ignore)
;;      ("'" ignore)
;;      ("\"" ignore)
;;      ("," ignore)
;;      ("<" ignore)
;;      ("." ignore)
;;      (">" ignore)
;;      ("/" ignore)
;;      ("?" ignore)
;; 
;;      ("C-u" scroll-down-command :first '(deactivate-mark))
;;      ("C-d" scroll-up-command :first '(deactivate-mark))))
;;   
;;   (setq ryo-modal-mode-cursor-type 'box)
;;  (setq ryo-modal-cursor-color "pink")))

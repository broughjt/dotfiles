(setq package-enable-at-startup nil)
(setq use-package-ensure-function 'ignore)
(setq package-archives nil)

(require 'bind-key)
(require 'seq)

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
    (dolist (var '("SSH_AUTH_SOCK"
                   "SSH_AGENT_PID"
                   "GPG_AGENT_INFO"
                   "GNUPGHOME"
                   "LANG"
                   "LC_CTYPE"
                   "NIX_SSL_CERT_FILE"
                   "NIX_PATH"))
      (add-to-list 'exec-path-from-shell-variables var))
    (exec-path-from-shell-initialize)))

(setq-default fill-column 80)
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode) 
(add-hook 'text-mode-hook #'display-fill-column-indicator-mode)

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
 org-latex-create-formula-image-program 'dvisvgm
 org-preview-latex-image-directory (concat local-directory "latex-previews/")
 org-latex-packages-alist
 '(("" "bussproofs" t) ("" "simplebnf" t) ("" "tikz-cd" t)) ;; ("" "notes" t)
 org-startup-with-latex-preview t
 org-startup-with-inline-images t)
(with-eval-after-load 'org
  (plist-put org-format-latex-options :background "Transparent")
  ;; TODO: Works for now?
  (plist-put org-format-latex-options :scale 0.5))

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

;; (bind-key "C-c d d"
;;           (lambda (&optional GOTO)
;;             (interactive)
;;             (org-capture GOTO "d")))
;; (bind-key "C-c r t"
;;           (lambda ()
;;             (interactive)
;;             (org-refile nil nil (list nil tasks-file nil nil))))
;; (bind-key "C-c a" 'org-agenda)

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
  ;; :bind
  ;; (("C-c n f" . org-roam-node-find)
  ;;  ("C-c n i" . org-roam-node-insert))
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

(use-package rustic
  :hook
  ((rustic-mode . eglot-ensure)
   ;; (rust-mode . flycheck-mode)
   )
  :config
  (setq rustic-lsp-client 'eglot)
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

;; (load-file (let ((coding-system-for-read 'utf-8))
;;              (shell-command-to-string "agda-mode locate")))

;; (load-file (let ((coding-system-for-read 'utf-8))
;;                 (shell-command-to-string "agda --emacs-mode locate")))

(defun jackson/agda-locate ()
  "Run `agda --emacs-mode locate` and echo the results."
  (interactive)
  (let ((coding-system-for-read 'utf-8))
    (message "%s" (shell-command-to-string "agda --emacs-mode locate"))))

(setq agda2-highlight-level 'interactive)

;; (use-package emms
;;   :config
;;   (require 'emms-setup)
;;   (emms-all)
;;   (setq emms-source-file-default-directory
;;     (expand-file-name "~/share/music/"))
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
          (error "gopass show failed with exit code %d and message: %s"
                 exit-code
                 (buffer-string))))))
  (setq gptel-api-key (lambda () (jackson/gopass-show "openai-api-key1")))
  (setq gptel-default-mode 'org-mode))

(use-package agent-shell
  :init
  (setq agent-shell-openai-authentication
        (agent-shell-openai-make-authentication :login t)))

(use-package typst-ts-mode
  :hook
  ((typst-ts-mode . eglot-ensure))
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 `((typst-ts-mode) . ,(eglot-alternatives `("tinymist"))))))

;; Phelps

(defconst phelps-host "127.0.0.1")
(defconst phelps-port 3001)

(defvar phelps-notes-directory nil
  "Directory where Phelps note files are stored.")

(setq phelps-notes-directory "~/repositories/notes2/notes/")

(defun phelps--generate-uuid ()
  "Return a UUID string.
Uses `uuidgen' when available, otherwise falls back to the `uuidgen' shell command."
  (cond
   ((executable-find "uuidgen")
    (string-trim (shell-command-to-string "uuidgen")))
   (t (user-error "No UUID generator available"))))

(defun phelps--slugify (string)
  "Return a filesystem-safe slug from STRING."
  (let* ((lower (downcase string))
         (clean (replace-regexp-in-string "[^a-z0-9]+" "-" lower))
         (squeezed (replace-regexp-in-string "-+" "-" clean))
         (trimmed (replace-regexp-in-string "^-\\|-$" "" squeezed)))
    trimmed))

(defun phelps--request (host port data)
  (let* ((request (concat (json-serialize data) "\n"))
         (message request)
         (buffer (generate-new-buffer "*notes-temporary*"))
         (process (open-network-stream
                   "notes-tcp"
                   buffer
                   host
                   port
                   :nowait nil
                   :type 'plain)))
    (unwind-protect
        (progn
          (process-send-string process request)
          (while (accept-process-output process))
          (with-current-buffer buffer
            (goto-char (point-min))
            (let ((string (buffer-substring-no-properties
                           (point-min) (point-max))))
              (ignore-errors (json-read-from-string string)))))
      (delete-process process)
      (kill-buffer buffer))))

(defun phelps-get-notes-list ()
  (let* ((request '(('tag . "get_notes")))
         (response (phelps--request
                    phelps-host phelps-port request))
         (ok (assoc 'items response))
         (items (cdr (car (cdr ok)))))
    items))

(defun phelps-focus-id (id)
  (let* ((request `((tag . "focus_note")
                    (id . ,id))))
    ;; Eh just assume it worked
    (phelps--request phelps-host phelps-port request)
    nil))

(defun phelps-note-read (notes)
  "Return the selected note item from the notes list"
  (let* ((table (mapcar (lambda (note)
                          (cons (alist-get 'title note) note))
                        notes))
         (choice (completing-read "Note: " table)))
    (alist-get choice table nil nil #'string=)))

(defun phelps-goto-note (note)
  "Open NOTE's Typst file and jump to its labeled heading.
NOTE is an alist containing at least `id' and `path' entries."
  (let* ((path (alist-get 'path note))
         (id (alist-get 'id note)))
    (unless path
      (user-error "Note missing path: %S" note))
    (unless id
      (user-error "Note missing id: %S" note))
    (find-file path)
    (goto-char (point-min))
    (if (search-forward (format "<note:%s>" id) nil t)
        (beginning-of-line)
      (message "Label not found for note id %s in %s" id path))))

(defconst phelps-link-regex
  (rx "#link("
      (? "\"")
      "note://"
      (group (repeat 8 hex-digit) "-" (repeat 4 hex-digit) "-" (repeat 4 hex-digit)
             "-" (repeat 4 hex-digit) "-" (repeat 12 hex-digit))
      (? "\"")
      ")"
      (? "[" (*? (or "\n" nonl)) "]")))

(defun phelps-link-id-at-point ()
  "Return plist the uuid for the #link containing point, or nil."
  (let* ((p (point))
         (hit nil))
    (save-excursion
      (goto-char (point-min))
      (while (and (not hit) (re-search-forward phelps-link-regex nil t))
        (let ((start (match-beginning 0))
              (end   (match-end 0)))
          (if (< p start)
              (setq hit nil) ; beyond point; stop
            (when (<= p end)
              (setq hit (match-string-no-properties 1)))))))
    hit))

(defconst phelps-note-uuid-regex
  (rx "<note:"
      (group (repeat 8 hex-digit) "-" (repeat 4 hex-digit) "-"
             (repeat 4 hex-digit) "-" (repeat 4 hex-digit) "-"
             (repeat 12 hex-digit))
      ">"))

(defun phelps-note-id-at-point ()
  "Return the UUID of the closest <note:...> label to point, or nil."
  (let* ((p (point))
         (best-id nil)
         (best-distance nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward phelps-note-uuid-regex nil t)
        (let* ((start (match-beginning 0))
               (distance (abs (- p start))))
          (when (or (null best-distance) (< distance best-distance))
            (setq best-distance distance)
            (setq best-id (match-string-no-properties 1))))))
    best-id))
  ;; (save-excursion
  ;;   (let* ((p (point)))
  ;;     (goto-char (point-min))
  ;;     (let (best-id best-distance)
  ;;       (while (re-search-forward phelps-note-uuid-regex nil t)
  ;;         (let* ((start (match-beginning 0))
  ;;                (distance (abs (- p start))))
  ;;           (when (or (null best-distance) (< distance best-distance))
  ;;             (setq best-distance distance)
  ;;             (setq best-id (match-string-no-properties 1)))))
  ;;         best-id))))

;; (defun phelps-note-id-at-point ()
;;   "Return the Typst note UUID for the section containing point, or nil."
;;   (save-excursion
;;     (let* ((heading (rx line-start (* space) (= 1 6 "=") (+ space)))
;;            (label   (rx "<note:"
;;                         (group (repeat 8 hex-digit) "-" (repeat 4 hex-digit) "-"
;;                                (repeat 4 hex-digit) "-" (repeat 4 hex-digit) "-"
;;                                (repeat 12 hex-digit))
;;                         ">")))
;;       (when (re-search-backward heading nil t)
;;         (let ((line (buffer-substring-no-properties
;;                      (line-beginning-position) (line-end-position))))
;;           (when (string-match label line)
;;             (match-string 1 line)))))))

;; (defun phelps-note-id-at-point ()
;;   "Return the UUID for the closest heading above point that has a <note:…> label, or nil."
;;   (save-excursion
;;     (beginning-of-line)
;;     (let ((heading-re (rx line-start (* space) (= 1 6 "=") (+ space)))
;;           (label-re   (rx "<note:"
;;                           (group (repeat 8 hex-digit) "-" (repeat 4 hex-digit) "-"
;;                                  (repeat 4 hex-digit) "-" (repeat 4 hex-digit) "-"
;;                                  (repeat 12 hex-digit))
;;                           ">")))
;;       (save-match-data
;;         (catch 'found
;;           (while (re-search-backward heading-re nil t)
;;             (let ((line (buffer-substring-no-properties
;;                          (line-beginning-position) (line-end-position))))
;;               (when (string-match label-re line)
;;                 (throw 'found (match-string 1 line)))))
;;           nil)))))

;; Phelps commands

(defun phelps-follow-note-link ()
  "Follow the note link under point to its Typst heading."
  (interactive)
  (let* ((id (phelps-link-id-at-point)))
    (unless id
      (user-error "No note id in link at point"))
    (let* ((notes (phelps-get-notes-list))
           (note (seq-find (lambda (n) (string= (alist-get 'id n) id))
                           notes)))
      (unless note
        (user-error "No note found for id %s" id))
      (phelps-goto-note note))))

(defun phelps-find-note ()
  "Select a note and visit its Typst file."
  (interactive)
  (let* ((notes (phelps-get-notes-list))
         (note (phelps-note-read notes))
         (path (alist-get 'path note)))
    (if path
        (phelps-goto-note note)
      (message "No path for note: %S" note))))

(defun phelps-insert-note-link ()
  "Select a note and insert a #link(\"note://...\")[...] at point."
  (interactive)
  (let* ((notes (phelps-get-notes-list))
         (note (phelps-note-read notes))
         (id (alist-get 'id note))
         (title (alist-get 'title note)))
    (unless id
      (user-error "Selected note is missing an id"))
    (insert (format "#link(\"note://%s\")[%s]" id title))))

(defun phelps-create-note ()
  "Prompt for a title, create a Typst note file, and open it."
  (interactive)
  (unless phelps-notes-directory
    (user-error "Set `phelps-notes-directory' to create notes"))
  (let* ((title (read-string "Note title: "))
         (uuid (phelps--generate-uuid))
         (slug-base (phelps--slugify title))
         (slug (if (string-empty-p slug-base)
                   uuid
                 (format "%s-%s" uuid slug-base)))
         (directory (file-name-as-directory
                     (expand-file-name phelps-notes-directory)))
         (path (expand-file-name (format "%s.typ" slug) directory)))
    (unless (file-directory-p directory)
      (make-directory directory t))
    (when (file-exists-p path)
      (user-error "Note file already exists: %s" path))
    (with-temp-file path
      (insert (format "= %s <note:%s>\n\n" title uuid)))
    (find-file path)
    (goto-char (point-min))
    (forward-line 2)))

(defun phelps-focus-note-at-point ()
  "Navigate the frontend to the note at the point"
  (interactive)
  (let* ((id (phelps-note-id-at-point)))
    (phelps-focus-id id)))

;; Keybindings
(bind-key "C-c n f" #'phelps-find-note)
(bind-key "C-c n i" #'phelps-insert-note-link)
(bind-key "C-c n g" #'phelps-follow-note-link)
(bind-key "C-c n c" #'phelps-create-note)
(bind-key "C-c n n" #'phelps-focus-note-at-point)

;;; -*- lexical-binding: t; -*-

;; Phelps

(require 'json)
(require 'calc)

(defconst phelps-host "127.0.0.1")
(defconst phelps-port 3001)

(defvar phelps-notes-directory nil
  "Directory where Phelps note files are stored.")

(setq phelps-notes-directory "~/repositories/notes/notes/")

(defvar phelps-label-file "~/repositories/notes/labels"
  "File where Phelps labels are stored.")

(defun phelps--generate-uuid ()
  "Return a UUID string.
Uses `uuidgen' when available, otherwise falls back to running
the `uuidgen' shell command."
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
  (let* ((request '((tag . "get_notes")))
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

(defun base36-parse (s)
  (math-read-number (concat "36#" s)))

(defun base36-format (n)
  (let* ((calc-number-radix 36)
         (digits (substring (math-format-number n) 3 nil)))
    (if (< (length digits) 4)
        (concat (make-string (- 4 (length digits)) ?0) digits)
      digits)))

(defun phelps-new-label ()
  "Increment the last base-36 label in `phelps-label-file` and copy it.
Reads the last line of `phelps-label-file` as a base-36 number, appends the
incremented value, and saves it to the kill ring."
  (interactive)
  (unless phelps-label-file
    (user-error "Set `phelps-label-file' to create a new label"))
  (unless (file-exists-p phelps-label-file)
    (user-error "Label file does not exist: %s" phelps-label-file))
  (let (last-line ends-with-newline)
    (with-temp-buffer
      (insert-file-contents phelps-label-file)
      (when (zerop (buffer-size))
        (user-error "Label file %s is empty" phelps-label-file))
      (goto-char (point-max))
      (setq ends-with-newline (eq (char-before) ?\n))
      (while (and (not (bobp))
                  (memq (char-before) '(?\n ?\r)))
        (backward-char))
      (when (bobp)
        (user-error "Label file %s has no labels" phelps-label-file))
      (forward-line 0)
      (setq last-line (string-trim (buffer-substring-no-properties
                                    (point) (line-end-position)))))
    (let* ((current (base36-parse last-line))
           (next (1+ current))
           (next-label (base36-format next)))
      (with-temp-buffer
        (unless ends-with-newline
          (insert "\n"))
        (insert next-label "\n")
        (write-region (point-min) (point-max)
                      phelps-label-file t 'silent))
      (kill-new next-label)
      (message "%s" next-label)
      next-label)))

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
         (title (alist-get 'title note))
         (selection (when (use-region-p)
                      (buffer-substring-no-properties
                       (region-beginning) (region-end))))
         (description (or selection title)))
    (unless id
      (user-error "Selected note is missing an id"))
    (when selection
      (delete-region (region-beginning) (region-end)))
    (insert (format "#link(\"note://%s\")[%s]" id description))))

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
      (insert (format "#import(\"../library/template.typ\"): *\n\n#show: template\n\n= %s <note:%s>\n\n" title uuid)))
    (find-file path)
    (goto-char (point-max))))

(defun phelps-focus-note-at-point ()
  "Navigate the frontend to the note at the point"
  (interactive)
  (let* ((id (phelps-note-id-at-point)))
    (phelps-focus-id id)))

(bind-key "C-c n f" #'phelps-find-note)
(bind-key "C-c n i" #'phelps-insert-note-link)
(bind-key "C-c n g" #'phelps-follow-note-link)
(bind-key "C-c n c" #'phelps-create-note)
(bind-key "C-c n n" #'phelps-focus-note-at-point)

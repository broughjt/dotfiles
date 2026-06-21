;;; -*- lexical-binding: t; -*-

;; Weibian
;;
;; Editing support for the Typst-bundle note system (the successor to Phelps).
;; Unlike the old phelps.el, this talks to no RPC process: it scans the note
;; source files directly.
;;
;; A "node" is the fundamental unit. Top-level notes live one-per-file in
;; `notes/<id>.typ' as `#show: node.with("<id>", [Title])'; Barb modules hold
;; many nodes via `#subnode("<id>", [Title], taxon: "...")[...]'. Ids are
;; four-digit base-36 in a single shared namespace. Links between nodes are
;; `#link-node("<id>")' (wiki-style, renders the target title) or
;; `#link-node("<id>")[description]'.

(require 'calc)
(require 'seq)
(require 'subr-x)

(defvar weibian-directory "~/repositories/notes-migration/"
  "Root of the Weibian notes repository.")

;;; Base-36 ids (shared namespace across notes and subnodes)

(defun base36-parse (s)
  "Parse base-36 string S into an integer."
  (math-read-number (concat "36#" s)))

(defun base36-format (n)
  "Format integer N as a zero-padded four-digit base-36 string."
  (let* ((calc-number-radix 36)
         (digits (downcase (substring (math-format-number n) 3 nil))))
    (if (< (length digits) 4)
        (concat (make-string (- 4 (length digits)) ?0) digits)
      digits)))

;;; Scanning

(defconst weibian--node-regexp
  "\\(node\\.with\\|subnode\\)(\"\\([0-9a-z]+\\)\",[[:space:]]*\\["
  "Match a `node.with(\"id\", [' or `subnode(\"id\", [' opening.
Group 1 is the kind, group 2 is the id; the match ends just past the
title's opening bracket.")

(defconst weibian--link-regexp
  "#link-node(\"\\([0-9a-z]+\\)\")\\(\\[\\)?"
  "Match a `#link-node(\"id\")' with an optional body opening.
Group 1 is the target id.")

(defun weibian--bracket-content (open)
  "Given OPEN, the position of a `[', return (CONTENT . END).
CONTENT is the bracket-balanced text between the brackets; END is just
after the matching `]'."
  (save-excursion
    (goto-char open)
    (let ((depth 0)
          (start (1+ open)))
      (while (and (not (eobp))
                  (progn
                    (pcase (char-after)
                      (?\[ (setq depth (1+ depth)))
                      (?\] (setq depth (1- depth))))
                    (forward-char)
                    (> depth 0))))
      (cons (buffer-substring-no-properties start (1- (point)))
            (point)))))

(defun weibian--normalize (string)
  "Collapse whitespace in STRING for display."
  (replace-regexp-in-string "[ \t\n]+" " " (string-trim string)))

(defun weibian--taxon-after (pos)
  "Return a `taxon: \"...\"' value found between POS and end of line, or nil."
  (save-excursion
    (goto-char pos)
    (when (re-search-forward "taxon:[[:space:]]*\"\\([a-z]+\\)\""
                             (line-end-position) t)
      (match-string-no-properties 1))))

(defun weibian--scan-file (file)
  "Return the list of node plists defined in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let (nodes)
      (while (re-search-forward weibian--node-regexp nil t)
        (let* ((kind (if (equal (match-string 1) "subnode") 'subnode 'note))
               (id (match-string-no-properties 2))
               (open (1- (match-end 0)))
               (bracket (weibian--bracket-content open))
               (title (weibian--normalize (car bracket)))
               (taxon (or (weibian--taxon-after (cdr bracket)) "note")))
          (push (list :id id :title title :taxon taxon
                      :file file :pos (match-beginning 0) :kind kind)
                nodes)
          (goto-char (cdr bracket))))
      (nreverse nodes))))

(defun weibian--source-files ()
  "Return the list of note source files to scan."
  (let* ((root (expand-file-name weibian-directory))
         (notes (expand-file-name "notes" root))
         (barb (expand-file-name "subtrees/barb/source" root)))
    (append
     (when (file-directory-p notes)
       (directory-files notes t "\\.typ\\'"))
     (when (file-directory-p barb)
       (directory-files-recursively barb "\\.typ\\'")))))

(defun weibian-nodes ()
  "Scan all note sources and return a flat list of node plists.
Each plist has :id, :title, :taxon, :file, :pos, and :kind."
  (apply #'append (mapcar #'weibian--scan-file (weibian--source-files))))

(defun weibian--next-id ()
  "Return the next free four-digit base-36 id across all nodes."
  (let ((highest 0))
    (dolist (node (weibian-nodes))
      (let ((id (plist-get node :id)))
        (when (string-match-p "\\`[0-9a-z]\\{4\\}\\'" id)
          (setq highest (max highest (base36-parse id))))))
    (base36-format (1+ highest))))

;;; Completion

(defun weibian--candidate-table ()
  "Return a hash table mapping candidate strings to node plists.
Titles shared by more than one node are disambiguated with their id."
  (let ((nodes (weibian-nodes))
        (counts (make-hash-table :test 'equal))
        (table (make-hash-table :test 'equal)))
    (dolist (node nodes)
      (let ((title (plist-get node :title)))
        (puthash title (1+ (gethash title counts 0)) counts)))
    (dolist (node nodes)
      (let* ((title (plist-get node :title))
             (candidate (if (> (gethash title counts) 1)
                            (format "%s (%s)" title (plist-get node :id))
                          title)))
        (puthash candidate node table)))
    table))

(defun weibian--affixation-function (table)
  "Return an affixation function over TABLE: taxon prefix, file suffix."
  (let ((root (expand-file-name weibian-directory)))
    (lambda (candidates)
      (mapcar
       (lambda (candidate)
         (let* ((node (gethash candidate table))
                (taxon (plist-get node :taxon))
                (file (file-relative-name (plist-get node :file) root)))
           (list candidate
                 (propertize (format "%-11s " taxon)
                             'face 'completions-annotations)
                 (propertize (concat "  " file)
                             'face 'completions-annotations))))
       candidates))))

(defun weibian--read-node (prompt)
  "Prompt with PROMPT for a node and return its plist."
  (let* ((table (weibian--candidate-table))
         (affix (weibian--affixation-function table))
         (collection
          (lambda (string predicate action)
            (if (eq action 'metadata)
                `(metadata (category . weibian-node)
                           (affixation-function . ,affix))
              (complete-with-action action table string predicate))))
         (choice (completing-read prompt collection nil t)))
    (gethash choice table)))

(defun weibian--visit (node)
  "Visit NODE's file and move point to its definition."
  (find-file (plist-get node :file))
  (goto-char (plist-get node :pos)))

(defun weibian--link-id-at-point ()
  "Return the target id of the `#link-node' at point, or nil.
Looks on the current line first, then falls back to the nearest link
beginning before point."
  (or (save-excursion
        (let ((p (point))
              (found nil))
          (goto-char (line-beginning-position))
          (while (and (not found)
                      (re-search-forward weibian--link-regexp
                                         (line-end-position) t))
            (let ((start (match-beginning 0))
                  (end (if (match-beginning 2)
                           (cdr (weibian--bracket-content (match-beginning 2)))
                         (point))))
              (when (and (<= start p) (<= p end))
                (setq found (match-string-no-properties 1)))))
          found))
      (save-excursion
        (when (re-search-backward weibian--link-regexp nil t)
          (match-string-no-properties 1)))))

;;; Commands

(defun weibian-find-note ()
  "Select a node and visit its definition."
  (interactive)
  (weibian--visit (weibian--read-node "Find node: ")))

(defun weibian-insert-node ()
  "Select a node and insert a `#link-node' to it at point.
With an active region, use it as the link description; if the region
matches the node title (or there is no region), insert the wiki-style
bare `#link-node(\"id\")'."
  (interactive)
  (let* ((region (when (use-region-p)
                   (buffer-substring-no-properties
                    (region-beginning) (region-end))))
         (node (weibian--read-node "Insert link to node: "))
         (id (plist-get node :id))
         (title (plist-get node :title))
         (description (and region (not (string= region title)) region)))
    (when (use-region-p)
      (delete-region (region-beginning) (region-end)))
    (insert (if description
                (format "#link-node(\"%s\")[%s]" id description)
              (format "#link-node(\"%s\")" id)))))

(defun weibian-goto-note-at-point ()
  "Follow the `#link-node' at point to its definition."
  (interactive)
  (let ((id (weibian--link-id-at-point)))
    (unless id
      (user-error "No #link-node at point"))
    (let ((node (seq-find (lambda (n) (equal (plist-get n :id) id))
                          (weibian-nodes))))
      (unless node
        (user-error "No node with id %s" id))
      (weibian--visit node))))

(defun weibian-new-note (title)
  "Create a new note under notes/ titled TITLE and visit it."
  (interactive "sNote title: ")
  (let* ((id (weibian--next-id))
         (dir (expand-file-name "notes" (expand-file-name weibian-directory)))
         (path (expand-file-name (concat id ".typ") dir)))
    (when (file-exists-p path)
      (user-error "Note file already exists: %s" path))
    (with-temp-file path
      (insert (format (concat "#import \"../note.typ\": *\n"
                              "#import \"../library/math.typ\": *\n\n"
                              "#show: node.with(\"%s\", [%s])\n\n")
                      id title)))
    (find-file path)
    (goto-char (point-max))))

(defun weibian-insert-subnode (title)
  "Insert a `#subnode' skeleton titled TITLE at point, with a fresh id."
  (interactive "sSubnode title: ")
  (let ((id (weibian--next-id)))
    (insert (format "#subnode(\"%s\", [%s])[\n  \n]\n" id title))
    (forward-line -2)
    (end-of-line)))

(bind-key "C-c n f" #'weibian-find-note)
(bind-key "C-c n i" #'weibian-insert-node)
(bind-key "C-c n g" #'weibian-goto-note-at-point)
(bind-key "C-c n c" #'weibian-new-note)
(bind-key "C-c n s" #'weibian-insert-subnode)

(provide 'weibian)

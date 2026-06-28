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
(require 'json)
(require 'seq)
(require 'subr-x)

(defconst weibian--project-marker "weibian.json"
  "Marker/config file at the root of a Weibian notes repository.")

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

;;; Project discovery and config

(defun weibian--project-root (&optional directory)
  "Return the Weibian project root containing DIRECTORY.
DIRECTORY defaults to `default-directory'. Signal `user-error' when not
inside a Weibian project."
  (let ((root (locate-dominating-file (or directory default-directory)
                                      weibian--project-marker)))
    (unless root
      (user-error "Not inside a Weibian project (no %s in this or any parent directory)"
                  weibian--project-marker))
    (file-name-as-directory (expand-file-name root))))

(defun weibian--project-config (&optional root)
  "Read and return weibian.json from ROOT as an alist."
  (let ((file (expand-file-name weibian--project-marker
                                (or root (weibian--project-root)))))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (json-parse-buffer :object-type 'alist :array-type 'list))))

(defun weibian--source-globs (&optional root)
  "Return the source glob strings from ROOT's weibian.json."
  (let* ((config (weibian--project-config root))
         (sources (alist-get 'sources config)))
    (unless (and (listp sources) (seq-every-p #'stringp sources))
      (user-error "%s sources must be a JSON array of strings"
                  weibian--project-marker))
    sources))

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

(defun weibian--tags-after (pos)
  "Return the `tags: (\"...\", ...)' strings between POS and end of line.
Returns nil when there is no tags argument. Tags are an array of string
literals; the corpus does not use them yet, but the node API supports
them and they are rendered as chips, so we scan them so search is ready."
  (save-excursion
    (goto-char pos)
    (when (re-search-forward "tags:[[:space:]]*(\\([^)]*\\))"
                             (line-end-position) t)
      (let ((inner (match-string-no-properties 1))
            (tags '())
            (start 0))
        (while (string-match "\"\\([^\"]*\\)\"" inner start)
          (push (match-string 1 inner) tags)
          (setq start (match-end 0)))
        (nreverse tags)))))

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
               (taxon (or (weibian--taxon-after (cdr bracket)) "note"))
               (tags (weibian--tags-after (cdr bracket))))
          (push (list :id id :title title :taxon taxon :tags tags
                      :file file :pos (match-beginning 0) :kind kind)
                nodes)
          (goto-char (cdr bracket))))
      (nreverse nodes))))

(defun weibian--glob->regexp (glob)
  "Translate a restricted shell GLOB into an anchored regexp over full paths.
`**' matches any number of path components (including none); `*' matches a
run of non-slash characters; `?' matches one non-slash character. Other
characters are matched literally."
  (let ((out "")
        (i 0)
        (n (length glob)))
    (while (< i n)
      (let ((c (aref glob i)))
        (cond
         ((and (eq c ?*) (< (1+ i) n) (eq (aref glob (1+ i)) ?*))
          ;; `**/' collapses an optional run of directories; a trailing `**'
          ;; matches the rest of the path.
          (cond
           ((and (< (+ i 2) n) (eq (aref glob (+ i 2)) ?/))
            (setq out (concat out "\\(?:.*/\\)?")
                  i (+ i 3)))
           (t (setq out (concat out ".*")
                    i (+ i 2)))))
         ((eq c ?*) (setq out (concat out "[^/]*") i (1+ i)))
         ((eq c ??) (setq out (concat out "[^/]") i (1+ i)))
         (t (setq out (concat out (regexp-quote (char-to-string c)))
                  i (1+ i))))))
    (concat "\\`" out "\\'")))

(defun weibian--expand-glob (glob)
  "Expand absolute GLOB to a list of matching files.
Unlike `file-expand-wildcards', this supports `**' as a recursive
wildcard matching any number of intervening directories, matching the
`file/glob' semantics weibian.json's globs are written against. The
build tool reads these same globs, so the two must agree on `**'."
  (if (not (string-match-p "\\*\\*" glob))
      (file-expand-wildcards glob t)
    ;; Walk the tree from the static prefix (everything before the first
    ;; wildcard) and keep the files whose full path matches the glob.
    (let ((base (file-name-directory
                 (substring glob 0 (string-match "[*?]" glob))))
          (regexp (weibian--glob->regexp glob)))
      (when (file-directory-p base)
        (seq-filter (lambda (file) (string-match-p regexp file))
                    (directory-files-recursively base ".*"))))))

(defun weibian--source-files (&optional root)
  "Return the list of note source files to scan for ROOT.
Source globs are read from weibian.json."
  (let ((root (weibian--project-root root)))
    (delete-dups
     (sort
      (apply #'append
             (mapcar (lambda (glob)
                       (weibian--expand-glob (expand-file-name glob root)))
                     (weibian--source-globs root)))
      #'string<))))

(defun weibian-nodes (&optional root)
  "Scan all note sources and return a flat list of node plists.
Each plist has :id, :title, :taxon, :file, :pos, and :kind."
  (apply #'append (mapcar #'weibian--scan-file (weibian--source-files root))))

(defun weibian--next-id (&optional root)
  "Return the next free four-digit base-36 id across all nodes in ROOT."
  (let ((highest 0))
    (dolist (node (weibian-nodes root))
      (let ((id (plist-get node :id)))
        (when (string-match-p "\\`[0-9a-z]\\{4\\}\\'" id)
          (setq highest (max highest (base36-parse id))))))
    (base36-format (1+ highest))))

;;; Completion

(defun weibian--candidate (node)
  "Return the completion candidate string for NODE.
The visible text is the title; the id, taxon, and tags are appended as
an `invisible' suffix. The characters stay in the string, so completion
styles match on them (type an id, taxon, or tag to narrow) and the hash
lookup resolves, but the minibuffer hides text carrying a non-nil
`invisible' property, so the displayed list stays titles only. Including
the id makes every candidate unique, which is why identically-titled
nodes no longer need a visible \"(id)\" suffix to disambiguate."
  (let ((title (plist-get node :title))
        (id (plist-get node :id))
        (taxon (plist-get node :taxon))
        (tags (plist-get node :tags)))
    (concat title
            (propertize (concat " " id " " taxon
                                (and tags (concat " " (string-join tags " "))))
                        'invisible t))))

(defun weibian--candidate-table (&optional root)
  "Return a hash table mapping candidate strings to node plists for ROOT.
See `weibian--candidate' for the candidate format."
  (let ((table (make-hash-table :test 'equal)))
    (dolist (node (weibian-nodes root))
      (puthash (weibian--candidate node) node table))
    table))

(defun weibian--affixation-function (table &optional root)
  "Return an affixation function over TABLE: taxon prefix, file suffix."
  (let ((root (weibian--project-root root)))
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
  (let* ((root (weibian--project-root))
         (table (weibian--candidate-table root))
         (affix (weibian--affixation-function table root))
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
                          (weibian-nodes (weibian--project-root)))))
      (unless node
        (user-error "No node with id %s" id))
      (weibian--visit node))))

(defun weibian-new-note (title)
  "Create a new note under notes/ titled TITLE and visit it."
  (interactive "sNote title: ")
  (let* ((root (weibian--project-root))
         (id (weibian--next-id root))
         (dir (expand-file-name "notes" root))
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
  (let ((id (weibian--next-id (weibian--project-root))))
    (insert (format "#subnode(\"%s\", [%s])[\n  \n]\n" id title))
    (forward-line -2)
    (end-of-line)))

(bind-key "C-c n f" #'weibian-find-note)
(bind-key "C-c n i" #'weibian-insert-node)
(bind-key "C-c n g" #'weibian-goto-note-at-point)
(bind-key "C-c n c" #'weibian-new-note)
(bind-key "C-c n s" #'weibian-insert-subnode)

(provide 'weibian)

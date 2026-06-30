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
(require 'treesit)
(require 'url)

(defgroup weibian nil
  "Editing support for the Typst-bundle note system."
  :group 'tools
  :prefix "weibian-")

(defcustom weibian-server-url "http://127.0.0.1:3000"
  "Fallback base URL of the `weibian watch' dev server.
Used by `weibian-browse-node-at-point' only when the running server's URL
file (written by `weibian watch') is absent -- e.g. the watch is not
running, or used a non-default port the file would otherwise report."
  :type 'string)

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

(defun weibian--server-url (&optional root)
  "Return the running dev server's base URL for ROOT, else `weibian-server-url'.
`weibian watch' writes its chosen URL to a file under the project's watch
inputs directory; read it so navigation reaches the actual port even when
the scan did not land on the default."
  (let* ((root (weibian--project-root root))
         (file (expand-file-name ".typst-dependencies/watch-inputs/server.json"
                                 root)))
    (or (and (file-readable-p file)
             (ignore-errors
               (with-temp-buffer
                 (insert-file-contents file)
                 (goto-char (point-min))
                 (alist-get 'url (json-parse-buffer :object-type 'alist)))))
        weibian-server-url)))

;;; Scanning

(defun weibian--normalize (string)
  "Collapse whitespace in STRING for display."
  (replace-regexp-in-string "[ \t\n]+" " " (string-trim string)))

(defun weibian--treesit-root ()
  "Return the Typst tree-sitter root node for the current buffer."
  (unless (treesit-parser-list nil 'typst t)
    (treesit-parser-create 'typst))
  (treesit-buffer-root-node 'typst))

(defun weibian--treesit-walk (node fn)
  "Call FN on NODE and every descendant."
  (funcall fn node)
  (dotimes (i (treesit-node-child-count node))
    (weibian--treesit-walk (treesit-node-child node i) fn)))

(defun weibian--treesit-named-children (node)
  "Return NODE's named children."
  (treesit-node-children node t))

(defun weibian--treesit-node-text (node)
  "Return NODE's source text without text properties."
  (treesit-node-text node t))

(defun weibian--treesit-string-value (node)
  "Return the unquoted source value of Typst string NODE."
  (when (and node (string= (treesit-node-type node) "string"))
    (let ((text (weibian--treesit-node-text node)))
      (if (and (>= (length text) 2)
               (eq (aref text 0) ?\")
               (eq (aref text (1- (length text))) ?\"))
          (substring text 1 -1)
        text))))

(defun weibian--treesit-content-text (node)
  "Return the source text inside Typst content NODE's outer brackets."
  (when (and node (string= (treesit-node-type node) "content"))
    (let ((text (weibian--treesit-node-text node)))
      (if (and (>= (length text) 2)
               (eq (aref text 0) ?\[)
               (eq (aref text (1- (length text))) ?\]))
          (substring text 1 -1)
        text))))

(defun weibian--treesit-call-head (call)
  "Return CALL's innermost function-call header.
For a Typst body application like `subnode(...)[body]', the outer `call'
has the header call as its item and the body content as a later child."
  (let ((item (treesit-node-child-by-field-name call "item")))
    (if (and item (string= (treesit-node-type item) "call"))
        (weibian--treesit-call-head item)
      call)))

(defun weibian--treesit-call-name (call)
  "Return CALL's callee name as source text, or nil."
  (let* ((head (weibian--treesit-call-head call))
         (item (treesit-node-child-by-field-name head "item")))
    (when item
      (weibian--treesit-node-text item))))

(defun weibian--treesit-call-group (call)
  "Return CALL's argument group node, or nil."
  (let ((head (weibian--treesit-call-head call)))
    (seq-find (lambda (child) (string= (treesit-node-type child) "group"))
              (weibian--treesit-named-children head))))

(defun weibian--treesit-call-body (call)
  "Return CALL's trailing content body node, or nil.
This is the `[body]' in `#subnode(...)[body]' or `#link-node(...)[body]',
not a positional content argument inside the parenthesized group."
  (let ((head (weibian--treesit-call-head call)))
    (seq-find (lambda (child)
                (and (string= (treesit-node-type child) "content")
                     (>= (treesit-node-start child) (treesit-node-end head))))
              (weibian--treesit-named-children call))))

(defun weibian--treesit-arguments (call)
  "Return the named syntax nodes inside CALL's parenthesized argument group."
  (when-let* ((group (weibian--treesit-call-group call)))
    (seq-filter (lambda (child)
                  (not (string= (treesit-node-type child) "tagged")))
                (weibian--treesit-named-children group))))

(defun weibian--treesit-named-argument (call name)
  "Return the value node for CALL's named argument NAME, or nil."
  (when-let* ((group (weibian--treesit-call-group call)))
    (seq-some (lambda (child)
                (when (string= (treesit-node-type child) "tagged")
                  (let ((field (treesit-node-child-by-field-name child "field")))
                    (when (and field (string= (weibian--treesit-node-text field) name))
                      (seq-find (lambda (grandchild)
                                  (not (treesit-node-eq grandchild field)))
                                (weibian--treesit-named-children child))))))
              (weibian--treesit-named-children group))))

(defun weibian--treesit-string-argument (call name)
  "Return CALL's named string argument NAME, or nil."
  (weibian--treesit-string-value (weibian--treesit-named-argument call name)))

(defun weibian--treesit-tags-argument (call)
  "Return CALL's `tags: (...)' string values, or nil when absent."
  (when-let* ((tags-node (weibian--treesit-named-argument call "tags")))
    (let (tags)
      (weibian--treesit-walk
       tags-node
       (lambda (node)
         (when (string= (treesit-node-type node) "string")
           (push (weibian--treesit-string-value node) tags))))
      (nreverse tags))))

(defun weibian--treesit-node-plist (call kind &optional file)
  "Build a Weibian node plist for Typst CALL of KIND in FILE."
  (let* ((args (weibian--treesit-arguments call))
         (id (weibian--treesit-string-value (nth 0 args)))
         (title-node (nth 1 args))
         (title (and title-node
                     (weibian--normalize
                      (weibian--treesit-content-text title-node))))
         (taxon (or (weibian--treesit-string-argument call "taxon") "note"))
         (tags (weibian--treesit-tags-argument call))
         (supersedes (weibian--treesit-string-argument call "supersedes"))
         (head (weibian--treesit-call-head call))
         (plist (list :id id :title title :taxon taxon :tags tags
                      :file file :pos (treesit-node-start head) :kind kind)))
    (when supersedes
      (setq plist (plist-put plist :supersedes supersedes)))
    plist))

(defun weibian--treesit-node-calls ()
  "Return Typst calls that define Weibian nodes in the current buffer."
  (let (calls)
    (weibian--treesit-walk
     (weibian--treesit-root)
     (lambda (node)
       (when (string= (treesit-node-type node) "call")
         (let ((name (weibian--treesit-call-name node)))
           (cond
            ((string= name "node.with")
             (push (cons node 'note) calls))
            ((and (string= name "subnode")
                  (weibian--treesit-call-body node))
             (push (cons node 'subnode) calls)))))))
    (nreverse calls)))

(defun weibian--scan-file (file)
  "Return the list of node plists defined in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (let (nodes)
      (dolist (entry (weibian--treesit-node-calls))
        (pcase-let ((`(,call . ,kind) entry))
          (push (weibian--treesit-node-plist call kind file) nodes)))
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
Looks for a tree-sitter `link-node' call enclosing point first, then falls
back to the nearest link beginning before point."
  (save-excursion
    (save-restriction
      (widen)
      (let ((target (point))
            (containing nil)
            (containing-width nil)
            (previous nil)
            (previous-start -1))
        (weibian--treesit-walk
         (weibian--treesit-root)
         (lambda (node)
           (when (and (string= (treesit-node-type node) "call")
                      (string= (weibian--treesit-call-name node) "link-node"))
             (let* ((head (weibian--treesit-call-head node))
                    (args (weibian--treesit-arguments node))
                    (id (weibian--treesit-string-value (car args)))
                    (start (treesit-node-start head))
                    (end (treesit-node-end node)))
               (when id
                 (when (and (<= start target) (<= target end))
                   (let ((width (- end start)))
                     (when (or (not containing-width) (< width containing-width))
                       (setq containing id
                             containing-width width))))
                 (when (and (<= start target) (> start previous-start))
                   (setq previous id
                         previous-start start)))))))
        (or containing previous)))))

(defun weibian--node-at-point ()
  "Return the plist of the innermost node or subnode enclosing point.
A top-level `node.with' is the file root fallback; each `#subnode(...)[...]'
encloses its declaration through the end of its body."
  (save-excursion
    (save-restriction
      (widen)
      (let ((target (point))
            (file buffer-file-name)
            (root nil)
            (best nil)
            (best-beg -1))
        (dolist (entry (weibian--treesit-node-calls))
          (pcase-let ((`(,call . ,kind) entry))
            (let* ((plist (weibian--treesit-node-plist call kind file))
                   (head (weibian--treesit-call-head call))
                   (beg (treesit-node-start head))
                   (end (if (eq kind 'note)
                            (point-max)
                          (treesit-node-end call))))
              (cond
               ((eq kind 'note)
                (unless root
                  (setq root plist)))
               ((and (<= beg target) (<= target end) (> beg best-beg))
                (setq best plist
                      best-beg beg))))))
        (or best root)))))

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
  "Insert a `#subnode' skeleton titled TITLE at point, with a fresh id.
Leave the initial body line unindented so literate Agda code blocks can stay
flush-left; prose can still be indented manually or by `typst-ts-mode'."
  (interactive "sSubnode title: ")
  (let ((id (weibian--next-id (weibian--project-root))))
    (insert (format "#subnode(\"%s\", [%s])[\n\n]\n" id title))
    (forward-line -2)
    (end-of-line)))

(defun weibian--navigate-request (base id)
  "Ask the dev server at BASE to navigate its current tab to node ID.
Return the decoded JSON alist (keys `navigated' and `tabs') on success,
or nil when the server is unreachable or errors -- the caller then opens a
new browser tab instead."
  (let ((url-request-method "POST")
        (url-request-extra-headers '(("Content-Type" . "application/json")))
        (url-request-data (encode-coding-string (json-serialize `((id . ,id)))
                                                'utf-8)))
    (ignore-errors
      (with-current-buffer
          (url-retrieve-synchronously (concat base "/__navigate") t t 2)
        (goto-char (point-min))
        (when (re-search-forward "\n\n" nil t)
          (json-parse-buffer :object-type 'alist :false-object nil))))))

(defun weibian-browse-node-at-point (&optional new-tab)
  "Open the node or subnode enclosing point in the browser.
With a running `weibian watch', this navigates the most-recently-active
tab to the node, reusing it; if no tab is open it opens a new one. With a
prefix argument NEW-TAB, always open a new browser tab (e.g. to compare
two nodes side by side)."
  (interactive "P")
  (let* ((node (weibian--node-at-point))
         (id (and node (plist-get node :id))))
    (unless id
      (user-error "Point is not inside a node"))
    (let* ((base (weibian--server-url))
           (url (format "%s/%s.html" base id))
           (response (and (not new-tab) (weibian--navigate-request base id))))
      (cond
       ((and response (alist-get 'navigated response))
        (let ((tabs (alist-get 'tabs response)))
          (message "weibian: navigated to %s%s" id
                   (if (and (integerp tabs) (> tabs 1))
                       (format " (1 of %d tabs)" tabs)
                     ""))))
       (t
        (browse-url url)
        (message "weibian: opened %s in a new tab" id))))))

(bind-key "C-c n f" #'weibian-find-note)
(bind-key "C-c n i" #'weibian-insert-node)
(bind-key "C-c n g" #'weibian-goto-note-at-point)
(bind-key "C-c n c" #'weibian-new-note)
(bind-key "C-c n s" #'weibian-insert-subnode)
(bind-key "C-c n b" #'weibian-browse-node-at-point)

(provide 'weibian)

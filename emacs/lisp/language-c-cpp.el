;;; -*- lexical-binding: t; -*-

(defvar apheleia-mode-alist)
(defvar c-basic-offset)
(defvar c-ts-mode-indent-offset)
(defvar eglot-server-programs)

(declare-function apheleia-mode "apheleia" (&optional arg))
(declare-function eglot-ensure "eglot")

(defun jackson/c-family-project-has-clang-format-p ()
  "Return non-nil when the current project declares a clang-format style."
  (or (locate-dominating-file default-directory ".clang-format")
      (locate-dominating-file default-directory "_clang-format")))

(defun jackson/enable-c-family-apheleia-if-configured ()
  "Enable format-on-save for C-family buffers with project style config."
  (when (jackson/c-family-project-has-clang-format-p)
    (apheleia-mode 1)))

(use-package apheleia
  :hook ((c-mode . jackson/enable-c-family-apheleia-if-configured)
         (c++-mode . jackson/enable-c-family-apheleia-if-configured)
         (c-ts-mode . jackson/enable-c-family-apheleia-if-configured)
         (c++-ts-mode . jackson/enable-c-family-apheleia-if-configured))
  :config
  ;; Apheleia already ships clang-format entries for these modes. Keep the
  ;; mapping explicit so this module owns C-family formatting behavior.
  (setf (alist-get 'c-mode apheleia-mode-alist) 'clang-format)
  (setf (alist-get 'c++-mode apheleia-mode-alist) 'clang-format)
  (setf (alist-get 'c-ts-mode apheleia-mode-alist) 'clang-format)
  (setf (alist-get 'c++-ts-mode apheleia-mode-alist) 'clang-format))

(setq-default c-basic-offset 4)
(setq-default c-ts-mode-indent-offset 4)

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((c-mode c++-mode c-ts-mode c++-ts-mode)
                 . ("clangd" "--background-index" "--clang-tidy"))))

(use-package cc-mode
  :ensure nil
  :mode (("\\.c\\'" . c-ts-mode)
         ("\\.h\\'" . c-or-c++-ts-mode)
         ("\\.cc\\'" . c++-ts-mode)
         ("\\.cpp\\'" . c++-ts-mode)
         ("\\.cxx\\'" . c++-ts-mode)
         ("\\.c\\+\\+\\'" . c++-ts-mode)
         ("\\.hh\\'" . c++-ts-mode)
         ("\\.hpp\\'" . c++-ts-mode)
         ("\\.hxx\\'" . c++-ts-mode)
         ("\\.h\\+\\+\\'" . c++-ts-mode)
         ("\\.ixx\\'" . c++-ts-mode)
         ("\\.tcc\\'" . c++-ts-mode))
  :hook ((c-mode . eglot-ensure)
         (c++-mode . eglot-ensure)
         (c-ts-mode . eglot-ensure)
         (c++-ts-mode . eglot-ensure)))

(use-package cmake-ts-mode
  :ensure nil
  :mode (("CMakeLists\\.txt\\'" . cmake-ts-mode)
         ("\\.cmake\\'" . cmake-ts-mode)))

(provide 'language-c-cpp)

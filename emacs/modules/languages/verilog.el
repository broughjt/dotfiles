;;; -*- lexical-binding: t; -*-

(use-package verilog-mode
  :custom
  (verilog-indent-level 4)
  (verilog-case-indent 4)
  (verilog-cexp-indent 4)
  (verilog-indent-level-behavioral 4)
  (verilog-indent-level-declaration 4)
  (verilog-indent-level-module 4)
  (verilog-align-ifelse t)
  (verilog-auto-delete-trailing-whitespace t)
  (verilog-auto-newline nil)
  (verilog-auto-lineup nil)
  (verilog-highlight-grouping-keywords t)
  (verilog-highlight-modules t)
  (verilog-auto-endcomments nil))

;; If users feel compelled to add comments signaling the end of blocks then you
;; should change your language syntax

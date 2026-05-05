;;; -*- lexical-binding: t; -*-

(use-package pi-coding-agent
  :commands (pi-coding-agent pi-coding-agent-toggle pi-coding-agent-install-grammars)
  :init
  (defalias 'pi 'pi-coding-agent)
  :custom
  ;; (pi-coding-agent-input-window-height 10)
  ;; (pi-coding-agent-tool-preview-lines 10)
  ;; (pi-coding-agent-bash-preview-lines 5)
  ;; (pi-coding-agent-context-warning-threshold 70)
  ;; (pi-coding-agent-context-error-threshold 90)
  ;; (pi-coding-agent-visit-file-other-window t)
  )

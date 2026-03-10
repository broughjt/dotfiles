;;; -*- lexical-binding: t; -*-

(declare-function agent-shell-openai-make-authentication "agent-shell-openai")
(declare-function agent-shell-anthropic-make-authentication "agent-shell-anthropic")

(use-package agent-shell
  :config
  (setq agent-shell-openai-authentication
        (agent-shell-openai-make-authentication :login t))
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t)))

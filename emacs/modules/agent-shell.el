(use-package agent-shell
  :config
  (setq agent-shell-openai-authentication
        (agent-shell-openai-make-authentication :login t))
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t)))

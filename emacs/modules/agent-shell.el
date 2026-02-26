(use-package agent-shell
  :init
  (setq agent-shell-openai-authentication
        (agent-shell-openai-make-authentication :login t))
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t)))

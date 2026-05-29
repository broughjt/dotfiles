;;; -*- lexical-binding: t; -*-

(when (locate-library "ghostel")
  (use-package ghostel
    :commands (ghostel ghostel-other ghostel-project)
    :custom
    (ghostel-module-auto-install nil)))

(provide 'terminal)

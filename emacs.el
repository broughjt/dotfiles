(setq package-enable-at-startup nil)
(setq use-package-ensure-function 'ignore)
(setq package-archives nil)

(setq use-package-always-ensure t)
(eval-when-compile (require 'use-package))

(add-to-list 'default-frame-alist
	     '(font . "JetBrainsMono 12"))

(use-package evil
  :config
  (evil-mode 1))

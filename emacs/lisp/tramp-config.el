;;; -*- lexical-binding: t; -*-

(use-package tramp
  :demand t
  :config
  ;; Tramp asks the remote for a PATH with `getconf PATH', which yields
  ;; /bin:/usr/bin and so names none of the profile directories a Nix machine
  ;; keeps its binaries in. Without this, a remote command cannot see nix
  ;; itself, and everything that shells out to a project's development shell
  ;; will break. Scoped to ssh rather than set globally.
  (connection-local-set-profile-variables
   'jackson/tramp-own-path-profile
   `((tramp-remote-path . ,(cons 'tramp-own-remote-path tramp-remote-path))))
  (connection-local-set-profiles
   '(:application tramp :protocol "ssh") 'jackson/tramp-own-path-profile))

(provide 'tramp-config)

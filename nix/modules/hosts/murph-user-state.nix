{
  config,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
in
{
  systemd.tmpfiles.rules = [
    # Fish rewrites history via temporary files and rename, so persist a real
    # directory and point the normal history path at it with a symlink instead
    # of bind-mounting fish_history itself.
    "d ${localDirectory}/share/fish 0700 ${user} users -"
    "d ${localDirectory}/hacks 0755 ${user} users -"
    "d ${localDirectory}/hacks/fish 0700 ${user} users -"
    "d ${localDirectory}/hacks/fish/fish_history 0700 ${user} users -"
    "f ${localDirectory}/hacks/fish/fish_history/fish_history 0600 ${user} users -"
    "L+ ${localDirectory}/share/fish/fish_history - - - - ${localDirectory}/hacks/fish/fish_history/fish_history"

    # Keep SSH client state out of ~/.ssh. The private key is the only secret
    # persisted here; known_hosts is intentionally mutable but narrowly scoped.
    "d ${localDirectory}/secrets 0700 ${user} users -"
    "d ${localDirectory}/secrets/ssh 0700 ${user} users -"
    "d ${localDirectory}/hacks/ssh 0700 ${user} users -"
    "d ${localDirectory}/hacks/ssh/known_hosts 0700 ${user} users -"
    "f ${localDirectory}/hacks/ssh/known_hosts/known_hosts 0600 ${user} users -"
    "d ${localDirectory}/hacks/tmux 0700 ${user} users -"
    "d ${localDirectory}/hacks/tmux/resurrect 0700 ${user} users -"
    "d ${localDirectory}/hacks/tmux/resurrect/resurrect 0700 ${user} users -"

    # direnv allow/deny records are explicit trust decisions. Persist the
    # decisions without persisting all of direnv's data directory.
    "d ${localDirectory}/share/direnv 0700 ${user} users -"
    "d ${localDirectory}/share/direnv/allow 0700 ${user} users -"
    "d ${localDirectory}/share/direnv/deny 0700 ${user} users -"

    # Emacs known-projects list. Backups and auto-saves are persisted by its
    # Home Manager impermanence mixin; other Emacs state (eln-cache,
    # auto-save-list, transient, custom, bookmarks) is intentionally ephemeral
    # under ~/local/{cache,state}/emacs. Racket REPL history and the editable
    # scratch REPL file are persisted narrowly under hacks/emacs/racket-mode.
    "d ${localDirectory}/hacks/emacs 0700 ${user} users -"
    "d ${localDirectory}/hacks/emacs/projects 0700 ${user} users -"
    "f ${localDirectory}/hacks/emacs/projects/projects.eld 0600 ${user} users - nil"
    "d ${localDirectory}/hacks/emacs/racket-mode 0700 ${user} users -"

    # GnuPG: only durable subcomponents are persisted. GNUPGHOME itself is
    # ephemeral and only holds activation-managed symlinks plus throwaway
    # state (random_seed, locks, sockets, crls.d). pubring.kbx and
    # trustdb.gpg live in a persisted directory so gpg's temp+rename writes
    # do not get pinned by per-file impermanence binds. private-keys-v1.d
    # and openpgp-revocs.d are symlinked into the persisted secrets tree.
    "d ${localDirectory}/secrets/gnupg 0700 ${user} users -"
    "d ${localDirectory}/secrets/gnupg/private-keys-v1.d 0700 ${user} users -"
    "d ${localDirectory}/secrets/gnupg/openpgp-revocs.d 0700 ${user} users -"
    "d ${localDirectory}/state/gnupg 0700 ${user} users -"
    "d ${localDirectory}/share/gnupg 0700 ${user} users -"
    "L+ ${localDirectory}/share/gnupg/private-keys-v1.d - - - - ${localDirectory}/secrets/gnupg/private-keys-v1.d"
    "L+ ${localDirectory}/share/gnupg/openpgp-revocs.d - - - - ${localDirectory}/secrets/gnupg/openpgp-revocs.d"
  ];
}

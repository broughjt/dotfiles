{ ... }:

{
  # The known-projects list, plus the Racket REPL history and its editable
  # scratch file. Other Emacs state (eln-cache, auto-save-list, transient,
  # custom, bookmarks) is intentionally ephemeral under ~/local/{cache,state}.
  home.persistence.main.directories = [
    {
      directory = "local/hacks/emacs/projects";
      mode = "0700";
    }
    {
      directory = "local/hacks/emacs/racket-mode";
      mode = "0700";
    }
    {
      directory = "local/state/emacs/backups";
      mode = "0700";
    }
    {
      directory = "local/state/emacs/auto-saves";
      mode = "0700";
    }
  ];
}

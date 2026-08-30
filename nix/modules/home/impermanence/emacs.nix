{ ... }:

{
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

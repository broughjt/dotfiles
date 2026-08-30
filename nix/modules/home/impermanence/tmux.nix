{ ... }:

{
  # tmux-resurrect saves and restores session layouts.
  home.persistence.main.directories = [
    {
      directory = "local/hacks/tmux/resurrect";
      mode = "0700";
    }
  ];
}

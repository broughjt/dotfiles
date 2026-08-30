{ ... }:

{
  # Fish's data directory holds the history file alongside regenerable
  # completion caches.
  home.persistence.main.directories = [
    {
      directory = "local/share/fish";
      mode = "0700";
    }
  ];
}

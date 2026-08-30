{ ... }:

{
  # allow/deny records are explicit trust decisions. Persist the decisions
  # without persisting all of direnv's data directory.
  home.persistence.main.directories = [
    {
      directory = "local/share/direnv/allow";
      mode = "0700";
    }
    {
      directory = "local/share/direnv/deny";
      mode = "0700";
    }
  ];
}

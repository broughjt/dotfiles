{ ... }:

{
  # The private key is the only secret persisted here; known_hosts is
  # intentionally mutable but narrowly scoped, and gets a directory of its own
  # for the same rename-safety reason as fish history.
  home.persistence.main.directories = [
    {
      directory = "local/secrets/ssh";
      mode = "0700";
    }
    {
      directory = "local/hacks/ssh/known_hosts";
      mode = "0700";
    }
  ];
}

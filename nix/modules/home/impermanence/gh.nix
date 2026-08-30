{ ... }:

{
  # config.yml is a Home Manager store symlink; hosts.yml is gh's mutable
  # account metadata. Persist their shared directory so both can coexist.
  home.persistence.main.directories = [
    {
      directory = "local/config/gh";
      mode = "0700";
    }
  ];
}

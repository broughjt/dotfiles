{ config, ... }:

{
  home.persistence.main.directories = [
    {
      directory = "local/secrets/gnupg";
      mode = "0700";
    }
    {
      directory = "local/state/gnupg";
      mode = "0700";
    }
  ];

  gpg.stateDirectory = "${config.defaultDirectories.localDirectory}/state/gnupg";
}

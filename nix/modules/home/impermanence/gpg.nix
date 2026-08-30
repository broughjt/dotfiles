{ config, ... }:

let
  localDirectory = config.defaultDirectories.localDirectory;
in
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

  gpg.stateDirectory = "${localDirectory}/state/gnupg";
  gpg.secretsDirectory = "${localDirectory}/secrets/gnupg";
}

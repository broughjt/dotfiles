{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
  localDirectory = config.defaultDirectories.localDirectory;
in
{
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath config.gpg.secretsDirectory;
      mode = "0700";
    }
    {
      directory = toHomeRelativePath config.gpg.stateDirectory;
      mode = "0700";
    }
  ];

  gpg.stateDirectory = "${localDirectory}/state/gnupg";
  gpg.secretsDirectory = "${localDirectory}/secrets/gnupg";
}

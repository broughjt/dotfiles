{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
  localDirectory = config.defaultDirectories.localDirectory;
in
{
  # The private key is the only secret persisted here; known_hosts is
  # intentionally mutable but narrowly scoped, and gets a directory of its own
  # for the same rename-safety reason as fish history.
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath "${localDirectory}/secrets/ssh";
      mode = "0700";
    }
    {
      directory = toHomeRelativePath "${localDirectory}/hacks/ssh/known_hosts";
      mode = "0700";
    }
  ];
}

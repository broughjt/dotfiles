{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  # Fish's data directory holds the history file alongside regenerable
  # completion caches.
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath "${config.xdg.dataHome}/fish";
      mode = "0700";
    }
  ];
}

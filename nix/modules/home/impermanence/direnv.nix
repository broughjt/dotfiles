{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
  direnvDataDirectory = "${config.xdg.dataHome}/direnv";
in
{
  # allow/deny records are explicit trust decisions. Persist the decisions
  # without persisting all of direnv's data directory.
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath "${direnvDataDirectory}/allow";
      mode = "0700";
    }
    {
      directory = toHomeRelativePath "${direnvDataDirectory}/deny";
      mode = "0700";
    }
  ];
}

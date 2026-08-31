{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  # config.yml is a Home Manager store symlink; hosts.yml is gh's mutable
  # account metadata. Persist their shared directory so both can coexist.
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath "${config.xdg.configHome}/gh";
      mode = "0700";
    }
  ];
}

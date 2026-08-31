{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  # tmux-resurrect saves and restores session layouts.
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath (builtins.dirOf config.programs.tmux.resurrectDirectory);
      mode = "0700";
    }
  ];

  programs.tmux.resurrectDirectory = "${config.defaultDirectories.localDirectory}/hacks/tmux/resurrect/resurrect";
}

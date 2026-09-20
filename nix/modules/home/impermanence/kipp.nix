{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  imports = [
    ./direnv.nix
    ./fish.nix
    ./tmux.nix
    ./gh.nix
    ./claude-code.nix
    ./codex.nix
  ];

  home.persistence.main = {
    persistentStoragePath = "/persist";
    hideMounts = true;
    directories = [
      (toHomeRelativePath config.defaultDirectories.repositoriesDirectory)
      (toHomeRelativePath config.defaultDirectories.scratchDirectory)
      # Not ./ssh.nix, which also persists an outbound key kipp does not have.
      {
        directory = toHomeRelativePath "${config.defaultDirectories.localDirectory}/hacks/ssh/known_hosts";
        mode = "0700";
      }
    ];
  };
}

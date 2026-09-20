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
    ./ssh.nix
    ./claude-code.nix
    ./codex.nix
  ];

  home.persistence.main = {
    persistentStoragePath = "/persist";
    hideMounts = true;
    directories = [
      (toHomeRelativePath config.defaultDirectories.repositoriesDirectory)
      (toHomeRelativePath config.defaultDirectories.scratchDirectory)
    ];
  };
}

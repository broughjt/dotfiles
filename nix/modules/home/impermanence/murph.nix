{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  imports = [
    ./direnv.nix
    ./fish.nix
    ./ssh.nix
    ./tmux.nix
    ./emacs.nix
    ./gpg.nix
    ./firefox.nix
    ./gh.nix
    ./gnome-desktop.nix
    ./claude-code.nix
    ./codex.nix
  ];

  home.persistence.main = {
    persistentStoragePath = "/persist";
    hideMounts = true;
    directories = [
      (toHomeRelativePath config.defaultDirectories.repositoriesDirectory)
      (toHomeRelativePath config.defaultDirectories.scratchDirectory)
      (toHomeRelativePath config.defaultDirectories.shareDirectory)
    ];
  };
}

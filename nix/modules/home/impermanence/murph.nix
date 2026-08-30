{ ... }:

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
      "repositories"
      "scratch"
      "share"
    ];
  };
}

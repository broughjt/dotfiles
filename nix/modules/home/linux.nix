{
  homeDirectories,
  homeFish,
  homeGit,
  homeTmux,
  personal,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  toHomeRelativePath = import ../../lib/to-home-relative-path.nix { inherit config lib; };
  localDirectory = config.defaultDirectories.localDirectory;
  sshPublicKeyPath = toHomeRelativePath "${localDirectory}/secrets/ssh/id_ed25519.pub";
in
{
  imports = [
    personal
    homeDirectories
    homeFish
    homeGit
    homeTmux
  ];

  config = {
    home.stateVersion = "25.05";
    programs.home-manager.enable = true;
    home.homeDirectory = config.defaultDirectories.homeDirectory;

    xdg = {
      enable = true;
      binHome = "${localDirectory}/bin";
      cacheHome = "${localDirectory}/cache";
      configHome = "${localDirectory}/config";
      dataHome = "${localDirectory}/share";
      stateHome = "${localDirectory}/state";
    };

    home.packages = with pkgs; [
      fd
      go-grip
      jq
      killall
      lldb
      ripgrep
    ];

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    services.ssh-agent.enable = true;

    # Home Manager's fish module enables man-db cache generation by default so
    # fish can complete `man` topics via `apropos`. That creates a top-level
    # ~/.manpath symlink. Keep man pages available, but skip the per-user man-db
    # cache to avoid the home dotfile.
    programs.man.generateCaches = false;

    programs.git = {
      signing.key = "1BA5F1335AB45105";
      signing.signByDefault = config.programs.gpg.enable;
    };

    home.file.${sshPublicKeyPath} = {
      force = true;
      text = config.personal.sshPublicKey + "\n";
    };
  };
}

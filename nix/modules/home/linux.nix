{
  homeDirectories,
  homeFish,
  homeGit,
  homeTmux,
  personal,
}:

{
  config,
  pkgs,
  ...
}:

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

    xdg.enable = true;

    home.packages = with pkgs; [
      fd
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
  };
}

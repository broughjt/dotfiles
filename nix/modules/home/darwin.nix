{
  config,
  pkgs,
  ...
}:

{
  personal = {
    userName = "jtbroug";
    fullName = "Jackson Brough";
    email = "jtbroug@sandia.gov";
  };

  defaultDirectories.homeDirectory = "/Users/jtbroug";

  home = {
    username = config.personal.userName;
    homeDirectory = config.defaultDirectories.homeDirectory;
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;

  programs.git = {
    signing.signByDefault = false;
    settings = {
      commit.gpgSign = false;
      tag.gpgSign = false;
    };
  };

  xdg.enable = true;

  home.packages = with pkgs; [
    fd
    jq
    julia-mono
    lldb
    ripgrep
    spotify
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}

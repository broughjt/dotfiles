{
  config,
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

  xdg.enable = true;
}

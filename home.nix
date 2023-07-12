{ config, pkgs, ... }:

{
  home.username = "jackson";
  home.homeDirectory = "/home/jackson";

  # TODO: Copy huge comment
  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  programs.fish.enable = true;

  programs.git = {
    enable = true;
    userName = "Jackson Brough";
    userEmail = "jacksontbrough@gmail.com";
  };

  programs.alacritty.enable = true;

  programs.fuzzel.enable = true;

  programs.firefox = {
    enable = true;
    enableGnomeExtensions = false;
  };
}

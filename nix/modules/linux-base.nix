{ config, pkgs, ... }:

{
  nix.settings.trusted-users = [
    "root"
    config.personal.userName
  ];

  environment.systemPackages = with pkgs; [
    curl
    git
    neovim
    glibcInfo
    man-pages
  ];
  environment.shells = with pkgs; [
    bashInteractive
    fish
  ];

  programs.fish.enable = true;

  users.users.${config.personal.userName} = {
    isNormalUser = true;
    description = config.personal.fullName;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
    ];
    shell = pkgs.fish;
  };

  services.openssh.enable = true;

  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}

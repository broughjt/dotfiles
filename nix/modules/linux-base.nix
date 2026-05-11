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

  users.mutableUsers = false;

  users.users.root.hashedPasswordFile = "/persist/etc/passwords/root";

  users.users.${config.personal.userName} = {
    isNormalUser = true;
    uid = 1000;
    description = config.personal.fullName;
    hashedPasswordFile = "/persist/etc/passwords/${config.personal.userName}";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
    ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [ config.personal.sshPublicKey ];
  };

  services.openssh.enable = true;

  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}

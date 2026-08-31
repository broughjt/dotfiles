{
  config,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
in
{
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

  users.users.${user} = {
    isNormalUser = true;
    description = config.personal.fullName;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [ config.personal.sshPublicKey ];
  };

  services.openssh.enable = true;

  security.sudo.extraConfig = ''
    Defaults:${user} lecture=never
  '';
}

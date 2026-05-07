{ config, pkgs, ... }:

{
  home-manager.users.${config.personal.userName} = {
    programs.gh = {
      enable = true;
      settings.git_protocol = "ssh";
    };
  };
}

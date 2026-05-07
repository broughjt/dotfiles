{ config, pkgs, ... }:

{
  virtualisation.docker.enable = true;

  users.users.${config.personal.userName}.extraGroups = [ "docker" ];
}

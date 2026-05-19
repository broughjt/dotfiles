{ config, ... }:

let
  user = config.personal.userName;
  uid = toString config.users.users.${user}.uid;
  dockerConfigDirectory = "${config.defaultDirectories.localDirectory}/config/docker";
in
{
  virtualisation.docker.enable = true;

  users.users.${user}.extraGroups = [ "docker" ];

  # Docker CLI defaults to ~/.docker and does not follow XDG_CONFIG_HOME on its
  # own. Point it at the visible XDG config tree; do not persist this directory
  # unless we later decide Docker login credentials, custom contexts, or other
  # client-side state should survive reboot.
  systemd.tmpfiles.rules = [
    "d ${dockerConfigDirectory} 0700 ${user} users -"
  ];

  systemd.services."user@${uid}" = {
    overrideStrategy = "asDropin";
    environment.DOCKER_CONFIG = dockerConfigDirectory;
  };

  systemd.services."home-manager-${user}".environment.DOCKER_CONFIG = dockerConfigDirectory;

  home-manager.users.${user}.home.sessionVariables.DOCKER_CONFIG = dockerConfigDirectory;
}

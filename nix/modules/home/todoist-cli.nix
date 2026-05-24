{ todoistCliOverlay }:

{ config, pkgs, ... }:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
  todoistConfigDir = "${localDirectory}/config/todoist-cli";
in
{
  nixpkgs.overlays = [ todoistCliOverlay ];

  # todoist-cli stores account metadata and preferences at
  # $XDG_CONFIG_HOME/todoist-cli/config.json. The file normally references
  # tokens held by the system keyring, but can contain a plaintext token when
  # the keyring is unavailable.
  systemd.tmpfiles.rules = [
    "d ${todoistConfigDir} 0700 ${user} users -"
  ];

  home-manager.users.${user}.home.packages = [
    pkgs.todoist-cli
  ];
}

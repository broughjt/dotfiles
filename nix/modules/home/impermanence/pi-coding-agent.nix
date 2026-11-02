{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath config.programs.pi-coding-agent.configDir;
      mode = "0700";
    }
  ];

  programs.pi-coding-agent.configDir = "${config.defaultDirectories.localDirectory}/state/pi";
}

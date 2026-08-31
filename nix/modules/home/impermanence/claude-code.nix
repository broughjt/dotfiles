{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath config.programs.claude-code.configDir;
      mode = "0700";
    }
  ];

  programs.claude-code.configDir = "${config.defaultDirectories.localDirectory}/state/claude-code";
}

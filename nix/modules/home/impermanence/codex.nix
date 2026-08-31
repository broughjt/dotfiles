{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath config.codex.configDirectory;
      mode = "0700";
    }
  ];

  codex.configDirectory = "${config.defaultDirectories.localDirectory}/state/codex";
}

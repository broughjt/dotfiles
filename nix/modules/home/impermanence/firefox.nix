{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath config.programs.firefox.configPath;
      mode = "0700";
    }
  ];

  programs.firefox.configPath = toHomeRelativePath (
    "${config.defaultDirectories.localDirectory}/config/mozilla/firefox"
  );
}

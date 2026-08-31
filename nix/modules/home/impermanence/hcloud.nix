{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  # cli.toml is stateful, it holds the Hetzner Cloud API token.
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath "${config.xdg.configHome}/hcloud";
      mode = "0700";
    }
  ];
}

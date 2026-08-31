{ config, pkgs, ... }:

{
  home.packages = [ pkgs.hcloud ];

  # hcloud hardcodes ~/.config/hcloud/cli.toml instead of reading
  # XDG_CONFIG_HOME. Point it at the XDG path
  home.sessionVariables.HCLOUD_CONFIG = "${config.xdg.configHome}/hcloud/cli.toml";
}

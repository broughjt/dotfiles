{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  home.persistence.main.directories = [
    # GNOME Keyring is the Secret Service implementation the desktop
    # applications below store their credentials through. It is enabled by
    # services.desktopManager.gnome, so it is never selected independently.
    {
      directory = toHomeRelativePath "${config.xdg.dataHome}/keyrings";
      mode = "0700";
    }
    {
      directory = toHomeRelativePath "${config.xdg.configHome}/discord";
      mode = "0700";
    }
    {
      directory = toHomeRelativePath "${config.xdg.configHome}/Slack";
      mode = "0700";
    }
    {
      directory = toHomeRelativePath "${config.xdg.dataHome}/TelegramDesktop";
      mode = "0700";
    }
    {
      directory = toHomeRelativePath "${config.xdg.configHome}/spotify";
      mode = "0700";
    }
  ];
}

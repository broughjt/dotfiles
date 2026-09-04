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
    # The Electron profile holds login state and user configuration. It also
    # co-locates downloaded Claude Code and caches, so persisting the profile
    # retains those rebuildable files rather than trying to split one mutable
    # directory.
    {
      directory = toHomeRelativePath "${config.xdg.configHome}/Claude";
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

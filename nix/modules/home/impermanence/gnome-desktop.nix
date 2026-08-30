{ ... }:

{
  home.persistence.main.directories = [
    # GNOME Keyring is the Secret Service implementation the desktop
    # applications below store their credentials through. It is enabled by
    # services.desktopManager.gnome, so it is never selected independently.
    {
      directory = "local/share/keyrings";
      mode = "0700";
    }
    {
      directory = "local/config/discord";
      mode = "0700";
    }
    {
      directory = "local/config/Slack";
      mode = "0700";
    }
    {
      directory = "local/share/TelegramDesktop";
      mode = "0700";
    }
    {
      directory = "local/config/spotify";
      mode = "0700";
    }
  ];
}

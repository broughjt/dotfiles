{ config, ... }:

let
  user = config.personal.userName;
in
{
  home-manager.users.${user} = {
    xdg = {
      mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = "firefox.desktop";
          "text/xml" = "firefox.desktop";
          "application/xhtml+xml" = "firefox.desktop";
          "application/xml" = "firefox.desktop";
          "application/pdf" = "org.gnome.Evince.desktop";
          "x-scheme-handler/http" = "firefox.desktop";
          "x-scheme-handler/https" = "firefox.desktop";
          "x-scheme-handler/slack" = "slack.desktop";
        };
      };

      # Take ownership of the existing hand-written file. Its only previous
      # setting, the Slack URL handler, is preserved above.
      configFile."mimeapps.list".force = true;
    };
  };
}

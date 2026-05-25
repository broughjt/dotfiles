{
  config,
  lib,
  ...
}:

let
  user = config.personal.userName;
  firefoxConfigPath = "local/config/mozilla/firefox";
in
{
  home-manager.users.${user} = {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "text/xml" = "firefox.desktop";
        "application/xhtml+xml" = "firefox.desktop";
        "application/xml" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/slack" = "slack.desktop";
      };
    };

    # Home Manager adds the wrapped Firefox package itself to this internal
    # native-messaging-hosts list, which creates ~/.mozilla/native-messaging-hosts
    # even when there are no actual native messaging hosts. Suppress that empty
    # compatibility directory; add explicit native messaging hosts here later if
    # an extension needs one.
    mozilla.firefoxNativeMessagingHosts = lib.mkForce [ ];

    programs.firefox = {
      enable = true;
      # Explicitly use the XDG location even though home.stateVersion is 25.05,
      # whose Home Manager default is still the legacy ~/.mozilla/firefox path.
      # The profile remains valuable mutable state (logins, cookies, session
      # restore, extension state, places.sqlite), so this exact subtree is
      # persisted by the host impermanence module.
      configPath = firefoxConfigPath;

      policies = {
        OfferToSaveLogins = false;

        ExtensionSettings = {
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            installation_mode = "force_installed";
            default_area = "menupanel";
            private_browsing = true;
          };
        };
      };

      profiles.default = {
        id = 0;
        name = "default";
        path = "default";
        isDefault = true;

        settings = {
          # Blank startup/home/new-tab pages.
          "browser.startup.page" = 0;
          "browser.startup.homepage" = "about:blank";
          "browser.newtabpage.enabled" = false;

          # Avoid the first-run/default-browser prompts in a declarative setup.
          "browser.shell.checkDefaultBrowser" = false;
          "browser.aboutwelcome.enabled" = false;
        };

        search = {
          force = true;
          default = "ddg";
          privateDefault = "ddg";
          order = [
            "ddg"
            "google"
          ];
        };
      };
    };
  };
}

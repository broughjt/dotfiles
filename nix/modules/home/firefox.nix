{ lib, ... }:

{
  # Home Manager adds the wrapped Firefox package itself to this internal
  # native-messaging-hosts list, which creates ~/.mozilla/native-messaging-hosts
  # even when there are no actual native messaging hosts. Suppress that empty
  # compatibility directory.
  mozilla.firefoxNativeMessagingHosts = lib.mkForce [ ];

  programs.firefox = {
    enable = true;

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
        default = "google";
        privateDefault = "google";
        order = [
          "google"
          "ddg"
        ];
      };
    };
  };
}

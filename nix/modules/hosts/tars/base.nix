{ config, ... }:

let
  consolePasswordPath = "/var/lib/console-password";
in
{
  system.stateVersion = "26.05";

  # NetworkManager runs DHCP on any wired interface it has no profile for, which
  # is the rescue path when the Pi is somewhere whose Wi-Fi it does not know.
  # Wi-Fi profiles are staged by the install.
  networking.networkmanager.enable = true;
  services.resolved.enable = true;

  users.users = {
    ${config.personal.userName} = {
      uid = 1000;
      hashedPasswordFile = consolePasswordPath;
    };
    # Password is to protect people besides me with access to the GPIO UART pins
    # from logging in. SSH remains password-less.
    root.hashedPasswordFile = consolePasswordPath;
  };

  security.sudo.wheelNeedsPassword = false;

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "America/Denver";
}

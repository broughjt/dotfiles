{ config, ... }:

{
  system.stateVersion = "26.11";

  networking.hostName = "kipp";

  # NetworkManager runs DHCP on any wired interface it has no profile for, which
  # is all kipp has. It is also what makes a Wi-Fi card or dongle, should one
  # ever be fitted, an nmcli command rather than a rebuild.
  networking.networkmanager.enable = true;
  services.resolved.enable = true;

  users.users.${config.personal.userName}.uid = 1000;

  # kipp is where agents run, and an agent that cannot restart a service or
  # rebuild the system is not much use. Reaching the machine at all takes a key
  # or the tailnet, which is the real boundary, as on `case`.
  security.sudo.wheelNeedsPassword = false;

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "America/Denver";
}

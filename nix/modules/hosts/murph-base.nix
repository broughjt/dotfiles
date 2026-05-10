{
  lib,
  ...
}:

{
  system.stateVersion = "25.05";

  networking.hostName = "murph";
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  # Avahi is enabled on this host by the GNOME desktop stack. Enable NSS
  # integration so .local hostnames resolve through mDNS and avahi-daemon
  # does not warn about missing nss-mdns support.
  services.avahi.nssmdns4 = true;

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  console.keyMap = "us";

  time.timeZone = "America/Denver";
}

{
  dconf,
  desktopApps,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    dconf
    desktopApps
  ];

  config = {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;
    services.gnome.core-apps.enable = false;
    services.gnome.core-developer-tools.enable = false;
    services.gnome.games.enable = false;
    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      gnome-user-docs
    ];

    xdg.portal = {
      enable = true;
      config.common.default = [ "gnome" ];
    };

    home-manager.users.${config.personal.userName}.home.packages = with pkgs; [
      dconf-editor
      nautilus
    ];
  };
}

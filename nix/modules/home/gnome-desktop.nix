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
      # Prefer GNOME, but list the fallback implementations explicitly for
      # interfaces that xdg-desktop-portal-gnome does not provide (e.g. Secret
      # from gnome-keyring, and any GTK-only portal interfaces). This avoids
      # relying on deprecated UseIn fallback selection.
      config.common.default = [
        "gnome"
        "gtk"
        "gnome-keyring"
      ];
    };

    home-manager.users.${config.personal.userName} = {
      home.packages = with pkgs; [
        dconf-editor
        nautilus
      ];

      # File chooser / Nautilus sidebar bookmarks. Keep these declarative so
      # the mutable GTK bookmarks file is not state we need to persist.
      xdg.configFile."gtk-3.0/bookmarks" = {
        force = true;
        text = ''
          file://${config.defaultDirectories.shareDirectory}/documents
          file://${config.defaultDirectories.shareDirectory}/music
          file://${config.defaultDirectories.shareDirectory}/pictures
          file://${config.defaultDirectories.shareDirectory}/videos
        '';
      };
    };
  };
}

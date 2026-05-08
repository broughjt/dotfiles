{
  cosmic-manager,
  desktopApps,
}:

{ config, ... }:

let
  user = config.personal.userName;
  directories = config.defaultDirectories;
in
{
  imports = [ desktopApps ];

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.desktopManager.cosmic = {
    enable = true;
    xwayland.enable = true;
  };
  services.displayManager.cosmic-greeter.enable = true;

  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "1";

  home-manager.users.${user} =
    { config, ... }:
    let
      cosmicLib = config.lib.cosmic;
      mkPathFavorite =
        path:
        cosmicLib.mkRON "enum" {
          variant = "Path";
          value = [ path ];
        };
      mkSpawn =
        command:
        cosmicLib.mkRON "enum" {
          variant = "Spawn";
          value = [ command ];
        };
    in
    {
      imports = [ cosmic-manager.homeManagerModules.cosmic-manager ];

      wayland.desktopManager.cosmic = {
        enable = true;

        applets.app-list.settings.favorites = [
          "firefox"
          "com.mitchellh.ghostty"
          "com.system76.CosmicFiles"
          "com.system76.CosmicSettings"
          "discord"
          "slack"
          "spotify"
        ];

        shortcuts = [
          {
            description = cosmicLib.mkRON "optional" "Open Ghostty";
            key = "Super+T";
            action = mkSpawn "ghostty";
          }
          {
            description = cosmicLib.mkRON "optional" "Open Firefox";
            key = "Super+B";
            action = mkSpawn "firefox";
          }
          {
            description = cosmicLib.mkRON "optional" "Open COSMIC Files";
            key = "Super+F";
            action = mkSpawn "cosmic-files";
          }
          {
            key = "Super+Q";
            action = cosmicLib.mkRON "enum" "Close";
          }
        ];
      };

      programs.cosmic-files = {
        enable = true;
        settings = {
          favorites = [
            (mkPathFavorite directories.repositoriesDirectory)
            (mkPathFavorite directories.shareDirectory)
            (mkPathFavorite directories.scratchDirectory)
          ];
        };
      };
    };
}

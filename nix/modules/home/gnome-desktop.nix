{
  dconf,
  llmAgentsOverlay,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ dconf ];

  config = {
    nixpkgs.overlays = [ llmAgentsOverlay ];

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
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
      ];
      config.common.default = [ "gnome" ];
    };

    home-manager.users.${config.personal.userName} = {
      home.packages = with pkgs; [
        bubblewrap
        dconf-editor
        discord
        evince
        firefox
        hunspell
        hunspellDicts.en_US
        julia-mono
        llm-agents.claude-code
        llm-agents.claude-agent-acp
        llm-agents.codex
        llm-agents.codex-acp
        llm-agents.gemini-cli
        llm-agents.opencode
        llm-agents.pi
        nautilus
        nicotine-plus
        noto-fonts
        slack
        spotify
        strawberry
        vlc
        wl-clipboard
      ];
      home.sessionVariables.NIXOS_OZONE_WL = "1";

      fonts.fontconfig = {
        enable = true;
        defaultFonts.monospace = [
          "JuliaMono"
          "Noto Sans Mono"
        ];
        defaultFonts.sansSerif = [ "Noto Sans" ];
        defaultFonts.serif = [ "Noto Serif" ];
      };

      programs.ghostty = {
        enable = true;
        settings = {
          theme = "dark:3024 Night,light:3024 Day";
          font-family = "JuliaMono";
        };
      };

      programs.zed-editor = {
        enable = true;
        userSettings = {
          vim_mode = true;
        };
      };

      programs.beets = {
        enable = true;
        settings = {
          directory = "${config.defaultDirectories.shareDirectory}/music";
          import.move = "yes";
          plugins = [ "musicbrainz" ];
        };
      };
    };
  };
}

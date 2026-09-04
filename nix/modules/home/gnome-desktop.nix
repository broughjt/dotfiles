{
  config,
  pkgs,
  ...
}:

{
  imports = [ ./firefox.nix ];

  home.packages = with pkgs; [
    llm-agents.claude-desktop
    discord
    dconf-editor
    evince
    # Renders Markdown locally and opens it in a browser, so it belongs with
    # the graphical session rather than in the portable Linux profile.
    go-grip
    hunspell
    hunspellDicts.en_US
    inter
    julia-mono
    nerd-fonts.symbols-only
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    nautilus
    pinentry-gnome3
    slack
    source-serif
    spotify
    telegram-desktop
    wl-clipboard
  ];

  home.sessionVariables.NIXOS_OZONE_WL = "1";

  fonts.fontconfig = {
    enable = true;
    defaultFonts.monospace = [
      "JuliaMono"
      "Noto Sans Mono"
    ];
    defaultFonts.sansSerif = [
      "Inter"
      "Noto Sans"
    ];
    defaultFonts.serif = [
      "Source Serif 4"
      "Noto Serif"
    ];
    defaultFonts.emoji = [ "Noto Color Emoji" ];
  };

  services.gpg-agent.pinentry.package = pkgs.pinentry-gnome3;

  # tmux-yank needs a clipboard tool, but we need to set it here because TMUX
  # might be used in headless environments.
  programs.tmux.copyCommand = "${pkgs.wl-clipboard}/bin/wl-copy";

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "text/xml" = "firefox.desktop";
        "application/xhtml+xml" = "firefox.desktop";
        "application/xml" = "firefox.desktop";
        "application/pdf" = "org.gnome.Evince.desktop";
        "x-scheme-handler/claude" = "claude-desktop.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/slack" = "slack.desktop";
      };
    };

    userDirs = {
      enable = true;
      setSessionVariables = false;
      desktop = config.defaultDirectories.scratchDirectory;
      documents = "${config.defaultDirectories.shareDirectory}/documents";
      download = config.defaultDirectories.scratchDirectory;
      music = "${config.defaultDirectories.shareDirectory}/music";
      pictures = "${config.defaultDirectories.shareDirectory}/pictures";
      projects = config.defaultDirectories.repositoriesDirectory;
      publicShare = config.defaultDirectories.shareDirectory;
      templates = "${config.defaultDirectories.shareDirectory}/templates";
      videos = "${config.defaultDirectories.shareDirectory}/videos";
    };

    # File chooser / Nautilus sidebar bookmarks. Keep these declarative so
    # the mutable GTK bookmarks file is not state we need to persist.
    configFile."gtk-3.0/bookmarks" = {
      force = true;
      text = ''
        file://${config.defaultDirectories.shareDirectory}/documents
        file://${config.defaultDirectories.shareDirectory}/music
        file://${config.defaultDirectories.shareDirectory}/pictures
        file://${config.defaultDirectories.shareDirectory}/videos
      '';
    };
  };
}

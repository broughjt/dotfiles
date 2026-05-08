{ llmAgentsOverlay }:

{ config, pkgs, ... }:

{
  nixpkgs.overlays = [ llmAgentsOverlay ];

  home-manager.users.${config.personal.userName} = {
    home.packages = with pkgs; [
      bubblewrap
      discord
      evince
      firefox
      hunspell
      hunspellDicts.en_US
      inter
      julia-mono
      llm-agents.claude-code
      llm-agents.claude-agent-acp
      llm-agents.codex
      llm-agents.codex-acp
      llm-agents.gemini-cli
      llm-agents.opencode
      llm-agents.pi
      nicotine-plus
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      nerd-fonts.symbols-only
      papers
      slack
      source-serif
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

    programs.ghostty = {
      enable = true;
      settings = {
        theme = "dark:3024 Night,light:3024 Day";
        font-family = "JuliaMono";
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
}

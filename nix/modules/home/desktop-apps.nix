{ llmAgentsOverlay }:

{ config, pkgs, ... }:

{
  nixpkgs.overlays = [ llmAgentsOverlay ];

  home-manager.users.${config.personal.userName} = {
    home.packages = with pkgs; [
      bubblewrap
      discord
      evince
      hunspell
      hunspellDicts.en_US
      inter
      julia-mono
      llm-agents.claude-code
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      nerd-fonts.symbols-only
      slack
      source-serif
      spotify
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

  };
}

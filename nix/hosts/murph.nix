{
  nixpkgs,
  home-manager,
  nixosModules,
}:

nixpkgs.lib.nixosSystem {
  modules = with nixosModules; [
    murphHardware
    murphBase
    diskoModule
    impermanenceModule
    murphDisko
    murphImpermanence
    murphSuspendDiagnostics
    nixSettings
    linuxBase
    llmAgents
    tailscale
    utahWireless
    docker
    home-manager.nixosModules.home-manager
    personal
    homeDirectories
    homeLinux
    gnomeDesktop
    browserTools
    gh
    gpg
    pass
    agentSkills
    plaidSync
    codex
    firefox
    mimeApps
    ghostty
    vlc
    emacs
    (
      { config, ... }:
      {
        home-manager.users.${config.personal.userName} = {
          imports = [ homeClaudeCode ];
          agentInstructions.machineFile = ../../agents/machines/murph.md;

          # Claude Code defaults to ~/.claude. Redirect it into the XDG-ish
          # layout so murph-user-persistence.nix can persist one directory.
          programs.claude-code.configDir = "${config.defaultDirectories.localDirectory}/state/claude-code";
        };
      }
    )
  ];
}

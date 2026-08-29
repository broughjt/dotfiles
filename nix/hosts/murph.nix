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
        };
      }
    )
  ];
}

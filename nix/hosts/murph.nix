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
    firefox
    mimeApps
    ghostty
    vlc
    emacs
    (
      { config, ... }:
      {
        home-manager.users.${config.personal.userName} = {
          imports = [
            homeClaudeCode
            homeCodex
          ];
          agentInstructions.machineFile = ../../agents/machines/murph.md;

          programs.claude-code.configDir = "${config.defaultDirectories.localDirectory}/state/claude-code";

          codex.configDirectory = "${config.defaultDirectories.localDirectory}/state/codex";
        };
      }
    )
  ];
}

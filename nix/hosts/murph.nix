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
    emacsPackageSet
    (
      { config, ... }:
      {
        home-manager.users.${config.personal.userName} = {
          imports = [
            homeEmacs
            homeClaudeCode
            homeCodex
            homeGh
            homeGhostty
            homeGnomeDesktop
            homeGpg
            homePass
            homeVlc
            homeMurphImpermanence
          ];
          agentInstructions.machineFile = ../../agents/machines/murph.md;
        };
      }
    )
  ];
}

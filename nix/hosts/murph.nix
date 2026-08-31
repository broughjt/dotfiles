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
    gnomeDesktop
    emacsPackageSet
    (
      { config, ... }:
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${config.personal.userName} = {
            imports = [
              homeLinux
              homeLocalDirectory
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

            # Home Manager evaluates the user in a separate module graph, so
            # copy the shared option values from the NixOS configuration.
            personal = config.personal;
            defaultDirectories = config.defaultDirectories;
            agentInstructions.machineFile = ../../agents/machines/murph.md;
          };
        };
      }
    )
  ];
}

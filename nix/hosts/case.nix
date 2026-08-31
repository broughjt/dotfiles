{
  nixpkgs,
  home-manager,
  nixosModules,
}:

nixpkgs.lib.nixosSystem {
  modules = with nixosModules; [
    caseHardware
    caseBase
    caseAccess
    diskoModule
    caseDisko
    nixSettings
    linux
    ssh
    llmAgents
    tailscale
    home-manager.nixosModules.home-manager
    personal
    homeDirectories
    (
      { config, ... }:
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${config.personal.userName} = {
            # No homeLocalDirectory: `case` keeps the stock XDG directories.
            # The ~/local layout is murph's preference, not a portability
            # requirement, and every module below works without it.
            imports = [
              homeLinux
              homeClaudeCode
              homeCodex
              homeGh
            ];

            # Home Manager evaluates the user in a separate module graph, so
            # copy the shared option values from the NixOS configuration.
            personal = config.personal;
            defaultDirectories = config.defaultDirectories;
            agentInstructions.machineFile = ../../agents/machines/case.md;
          };
        };
      }
    )
  ];
}

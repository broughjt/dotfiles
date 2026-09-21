{
  nixpkgs,
  home-manager,
  nixosModules,
}:

nixpkgs.lib.nixosSystem {
  modules = with nixosModules; [
    kippHardware
    kippBase
    kippAccess
    diskoModule
    impermanenceModule
    kippDisko
    kippImpermanence
    nixSettings
    linux
    localDirectory
    ssh
    zram
    llmAgents
    tailscale
    docker
    home-manager.nixosModules.home-manager
    personal
    homeDirectories
    (
      { config, ... }:
      let
        inherit (config) personal defaultDirectories;
      in
      {
        ssh.knownHostsFile = "${defaultDirectories.localDirectory}/hacks/ssh/known_hosts/known_hosts";

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${personal.userName} =
            { config, ... }:
            {
              imports = [
                homeLinux
                homeLocalDirectory
                homeAgentDetach
                homeClaudeCode
                homeCodex
                homeGh
                homeKippImpermanence
              ];

              inherit personal defaultDirectories;
              agentInstructions.machineFile = ../../agents/machines/kipp.md;

              # Nobody is there to log gh in through a browser, so its API calls
              # use a token file. Git itself goes over SSH with kipp's own key.
              gh.tokenFile = "${config.xdg.configHome}/gh/token";
            };
        };
      }
    )
  ];
}

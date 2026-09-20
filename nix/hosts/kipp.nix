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
    llmAgents
    tailscale
    docker
    home-manager.nixosModules.home-manager
    personal
    homeDirectories
    (
      { config, lib, ... }:
      let
        inherit (config) personal defaultDirectories;
      in
      {
        # localDirectory points this at a key under ~/local/secrets. kipp holds
        # no outbound SSH key, as `case` does not.
        ssh.identityFile = lib.mkForce null;
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

              # With no outbound SSH key, kipp reaches GitHub over HTTPS with a
              # token the credential helper picks up.
              gh.tokenFile = "${config.xdg.configHome}/gh/token";
              programs.gh.settings.git_protocol = "https";
            };
        };
      }
    )
  ];
}

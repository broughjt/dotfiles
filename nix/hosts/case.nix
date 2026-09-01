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
      let
        inherit (config) personal defaultDirectories;
      in
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${personal.userName} =
            { config, ... }:
            {
              imports = [
                homeLinux
                homeAgentDetach
                homeClaudeCode
                homeCodex
                homeGh
              ];

              inherit personal defaultDirectories;
              agentInstructions.machineFile = ../../agents/machines/case.md;

              # `case` is headless, so a Claude auth token obtained from `claude
              # setup-token` is easier.
              claudeCode.oauthTokenFile = "${config.programs.claude-code.configDir}/oauth-token";

              # `case` holds no outbound SSH key, so it reaches GitHub over
              # HTTPS with a fine-grained token the credential helper picks up.
              gh.tokenFile = "${config.xdg.configHome}/gh/token";
              programs.gh.settings.git_protocol = "https";
            };
        };
      }
    )
  ];
}

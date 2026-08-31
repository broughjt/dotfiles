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
    nixSettings
    linux
    localDirectory
    ssh
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
            imports = [
              homeLinux
              homeLocalDirectory
            ];

            # Home Manager evaluates the user in a separate module graph, so
            # copy the shared option values from the NixOS configuration.
            personal = config.personal;
            defaultDirectories = config.defaultDirectories;
          };
        };
      }
    )
  ];
}

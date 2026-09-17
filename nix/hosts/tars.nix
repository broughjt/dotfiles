{
  nixos-raspberrypi,
  home-manager,
  nixosModules,
  instance,
}:

nixos-raspberrypi.lib.nixosSystem {
  modules = with nixosModules; [
    tarsHardware
    tarsBase
    tarsAccess
    diskoModule
    tarsDisko
    tarsZfs
    nixSettings
    linux
    ssh
    tailscale
    home-manager.nixosModules.home-manager
    personal
    homeDirectories
    instance
    (
      { config, ... }:
      let
        inherit (config) personal defaultDirectories;
      in
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${personal.userName} = {
            imports = [ homeLinux ];

            inherit personal defaultDirectories;
          };
        };
      }
    )
  ];
}

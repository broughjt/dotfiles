{
  tarsHardware,
  nixSettings,
  linuxBase,
  home-manager,
  personal,
  homeLinux,
  tarsAccess,
}:

{
  imports = [
    tarsHardware
    nixSettings
    linuxBase
    home-manager.nixosModules.home-manager
    personal
    homeLinux
    tarsAccess
  ];
}

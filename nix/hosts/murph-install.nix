{
  inputs,
  self,
  nixpkgs,
  home-manager,
  nixosModules,
}:

nixpkgs.lib.nixosSystem {
  specialArgs = {
    inherit inputs self;
  };
  modules = with nixosModules; [
    murphHardware
    diskoModule
    impermanenceModule
    murphDisko
    murphImpermanence
    nixSettings
    linuxBase
    home-manager.nixosModules.home-manager
    personal
    homeLinux
  ];
}

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
    nixSettings
    linuxBase
    docker
    home-manager.nixosModules.home-manager
    personal
    homeLinux
    cosmicDesktop
    gh
    gpg
    pass
    vaultixSecrets
    piCodingAgent
    kakoune
    emacs
  ];
}

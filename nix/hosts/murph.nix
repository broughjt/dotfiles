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
    murphBase
    diskoModule
    impermanenceModule
    murphDisko
    murphImpermanence
    nixSettings
    linuxBase
    docker
    home-manager.nixosModules.home-manager
    personal
    homeLinux
    gnomeDesktop
    browserTools
    googleTools
    gh
    gpg
    pass
    vaultixSecrets
    piCodingAgent
    todoistCli
    todoistElectron
    claudeCode
    firefox
    ghostty
    kakoune
    vlc
    emacs
  ];
}

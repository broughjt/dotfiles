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
    tailscale
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
    piCodingAgent
    todoistCli
    todoistElectron
    claudeCode
    firefox
    mimeApps
    ghostty
    kakoune
    vlc
    emacs
  ];
}

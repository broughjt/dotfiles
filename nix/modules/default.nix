{
  home-manager,
  nix-config,
  llmAgentsOverlay,
  emacsOverlays,
  disko,
  impermanence,
  vaultixInput,
  nixos-raspberrypi,
  configureEmacsPackage,
  piWebMinimalPackage,
}:

rec {
  personal = import ./personal.nix;
  nixSettings = import ./nix-settings.nix { inherit nix-config; };

  tarsHardware = import ./hosts/tars-hardware.nix { inherit nixos-raspberrypi; };
  tarsAccess = import ./hosts/tars-access.nix;
  tarsBase = import ./hosts/tars-base.nix {
    inherit
      tarsHardware
      nixSettings
      linuxBase
      home-manager
      personal
      homeLinux
      tarsAccess
      ;
  };
  murphHardware = import ./hosts/murph-hardware.nix;
  murphDisko = import ./hosts/murph-disko.nix;
  murphImpermanence = import ./hosts/murph-impermanence.nix;
  diskoModule = disko.nixosModules.disko;
  impermanenceModule = impermanence.nixosModules.impermanence;

  linuxBase = import ./linux-base.nix;
  docker = import ./docker.nix;

  homeDirectories = import ./home/directories.nix;
  homeLinux = import ./home/linux.nix { inherit homeDirectories; };
  desktopApps = import ./home/desktop-apps.nix { inherit llmAgentsOverlay; };
  gnomeDesktop = import ./home/gnome-desktop.nix { inherit dconf desktopApps; };
  dconf = import ./home/dconf.nix { inherit home-manager; };
  gh = import ./home/gh.nix;
  gpg = import ./home/gpg.nix;
  pass = import ./home/pass.nix;
  vaultixSecrets = import ./home/vaultix-secrets.nix { inherit vaultixInput; };
  piCodingAgent = import ./home/pi-coding-agent.nix { inherit piWebMinimalPackage; };
  kakoune = import ./home/kakoune.nix;
  tailscale = import ./tailscale.nix;
  emacs = import ./home/emacs.nix {
    inherit
      emacsOverlays
      configureEmacsPackage
      ;
  };
}

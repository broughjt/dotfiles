{
  home-manager,
  nix-config,
  llmAgentsOverlay,
  emacsOverlays,
  disko,
  impermanence,
  agenix,
  nixos-raspberrypi,
  configureEmacsPackage,
  piWebMinimalPackage,
  piMcpAdapterPackage,
  piSubagentsPackage,
  todoistCliOverlay,
  googleWorkspaceCliOverlay,
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
  murphBase = import ./hosts/murph-base.nix;
  murphDisko = import ./hosts/murph-disko.nix;
  murphImpermanence = import ./hosts/murph-impermanence.nix;
  diskoModule = disko.nixosModules.disko;
  impermanenceModule = impermanence.nixosModules.impermanence;

  linuxBase = import ./linux-base.nix;
  docker = import ./docker.nix;

  homeDirectories = import ./home/directories.nix;
  homeFish = import ./home/fish.nix;
  homeGit = import ./home/git.nix;
  homeLinux = import ./home/linux.nix {
    inherit
      homeDirectories
      homeFish
      homeGit
      personal
      ;
  };
  desktopApps = import ./home/desktop-apps.nix { inherit llmAgentsOverlay; };
  browserTools = import ./home/browser-tools.nix { inherit llmAgentsOverlay; };
  googleTools = import ./home/google-tools.nix { inherit googleWorkspaceCliOverlay; };
  gnomeDesktop = import ./home/gnome-desktop.nix { inherit dconf desktopApps; };
  dconf = import ./home/dconf.nix;
  gh = import ./home/gh.nix;
  gpg = import ./home/gpg.nix;
  pass = import ./home/pass.nix;
  piCodingAgent = import ./home/pi-coding-agent.nix {
    inherit
      piWebMinimalPackage
      piMcpAdapterPackage
      piSubagentsPackage
      todoistCliOverlay
      ;
    agenixHome = agenix.homeManagerModules.default;
  };
  todoistCli = import ./home/todoist-cli.nix { inherit todoistCliOverlay; };
  todoistElectron = import ./home/todoist-electron.nix;
  claudeCode = import ./home/claude-code.nix { inherit llmAgentsOverlay; };
  firefox = import ./home/firefox.nix;
  mimeApps = import ./home/mime-apps.nix;
  ghostty = import ./home/ghostty.nix;
  kakoune = import ./home/kakoune.nix;
  vlc = import ./home/vlc.nix;
  tailscale = import ./tailscale.nix;
  emacsHome = import ./home/emacs-home.nix { inherit configureEmacsPackage; };
  emacs = import ./home/emacs.nix {
    inherit
      emacsOverlays
      emacsHome
      ;
  };
}

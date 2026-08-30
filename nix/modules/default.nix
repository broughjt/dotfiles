{
  home-manager,
  nix-config,
  llmAgentsOverlay,
  emacsOverlays,
  disko,
  impermanence,
  agenix,
  configureEmacsPackage,
}:

rec {
  personal = import ./personal.nix;
  nixSettings = import ./nix-settings.nix { inherit nix-config; };

  murphHardware = import ./hosts/murph-hardware.nix;
  murphBase = import ./hosts/murph-base.nix;
  murphDisko = import ./hosts/murph-disko.nix;
  murphImpermanence = import ./hosts/murph-impermanence.nix;
  murphSuspendDiagnostics = import ./hosts/murph-suspend-diagnostics.nix;
  diskoModule = disko.nixosModules.disko;
  impermanenceModule = impermanence.nixosModules.impermanence;

  linuxBase = import ./linux-base.nix;
  # Overlays are a host concern. With home-manager.useGlobalPkgs the Home
  # Manager modules share the system package set and cannot add their own.
  llmAgents = {
    nixpkgs.overlays = [ llmAgentsOverlay ];
  };
  docker = import ./docker.nix;

  homeDirectories = import ./home/directories.nix;
  homeFish = import ./home/fish.nix;
  homeGh = import ./home/gh.nix;
  homeGit = import ./home/git.nix;
  homeLinux = import ./home/linux.nix {
    inherit
      homeDirectories
      homeFish
      homeGit
      personal
      ;
  };
  homeDarwin = import ./home/darwin.nix;
  desktopApps = import ./home/desktop-apps.nix { inherit llmAgentsOverlay; };
  gnomeDesktop = import ./home/gnome-desktop.nix { inherit dconf desktopApps; };
  dconf = import ./home/dconf.nix;
  gpg = import ./home/gpg.nix;
  homePass = import ./home/pass.nix;
  plaidSync = import ./home/plaid-sync.nix {
    agenixHome = agenix.homeManagerModules.default;
  };
  homeClaudeCode = import ./home/claude-code.nix;
  homeCodex = import ./home/codex.nix;
  firefox = import ./home/firefox.nix;
  mimeApps = import ./home/mime-apps.nix;
  homeGhostty = import ./home/ghostty.nix;
  vlc = import ./home/vlc.nix;
  tailscale = import ./tailscale.nix;
  utahWireless = import ./utah-wireless.nix;
  emacsHome = import ./home/emacs-home.nix { inherit configureEmacsPackage; };
  emacs = import ./home/emacs.nix {
    inherit
      emacsOverlays
      emacsHome
      ;
  };
}

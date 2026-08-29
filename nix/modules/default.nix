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
  homeDarwin = import ./home/darwin.nix;
  desktopApps = import ./home/desktop-apps.nix { inherit llmAgentsOverlay; };
  browserTools = import ./home/browser-tools.nix { inherit llmAgentsOverlay; };
  gnomeDesktop = import ./home/gnome-desktop.nix { inherit dconf desktopApps; };
  dconf = import ./home/dconf.nix;
  gh = import ./home/gh.nix;
  gpg = import ./home/gpg.nix;
  pass = import ./home/pass.nix;
  plaidSync = import ./home/plaid-sync.nix {
    agenixHome = agenix.homeManagerModules.default;
  };
  agentSkills = import ./home/agent-skills.nix;
  claudeCode = import ./home/claude-code.nix { inherit llmAgentsOverlay; };
  codex = import ./home/codex.nix { inherit llmAgentsOverlay; };
  firefox = import ./home/firefox.nix;
  mimeApps = import ./home/mime-apps.nix;
  ghostty = import ./home/ghostty.nix;
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

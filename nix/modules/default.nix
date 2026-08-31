{
  home-manager,
  nix-config,
  llmAgentsOverlay,
  emacsOverlays,
  disko,
  impermanence,
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

  linux = import ./linux.nix;
  localDirectory = import ./local-directory.nix;
  ssh = import ./ssh.nix;
  # Overlays are a host concern. With home-manager.useGlobalPkgs the Home
  # Manager modules share the system package set and cannot add their own.
  llmAgents = {
    nixpkgs.overlays = [ llmAgentsOverlay ];
  };
  emacsPackageSet = {
    nixpkgs.overlays = emacsOverlays;
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
      homeTmux
      personal
      ;
  };
  homeDarwin = import ./home/darwin.nix;
  homeGnomeDesktop = import ./home/gnome-desktop.nix { inherit homeFirefox; };
  homeGnomeDesktopImpermanence = import ./home/impermanence/gnome-desktop.nix;
  gnomeDesktop = import ./gnome-desktop.nix { inherit dconf; };
  dconf = import ./dconf.nix;
  homeGpg = import ./home/gpg.nix;
  homePass = import ./home/pass.nix;
  homeClaudeCode = import ./home/claude-code.nix;
  homeClaudeCodeImpermanence = import ./home/impermanence/claude-code.nix;
  homeCodex = import ./home/codex.nix;
  homeCodexImpermanence = import ./home/impermanence/codex.nix;
  homeEmacsImpermanence = import ./home/impermanence/emacs.nix;
  homeFirefox = import ./home/firefox.nix;
  homeFirefoxImpermanence = import ./home/impermanence/firefox.nix;
  homeGhImpermanence = import ./home/impermanence/gh.nix;
  homeGhostty = import ./home/ghostty.nix;
  homeLocalDirectory = import ./home/local-directory.nix;
  homeGpgImpermanence = import ./home/impermanence/gpg.nix;
  homeMurphImpermanence = import ./home/impermanence/murph.nix;
  homeTmux = import ./home/tmux.nix;
  homeVlc = import ./home/vlc.nix;
  homeEmacs = import ./home/emacs.nix { inherit configureEmacsPackage; };
  tailscale = import ./tailscale.nix;
  utahWireless = import ./utah-wireless.nix;
}

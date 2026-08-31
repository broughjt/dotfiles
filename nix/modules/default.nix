{
  llmAgentsOverlay,
  emacsOverlays,
  disko,
  impermanence,
}:

{
  personal = import ./personal.nix;
  nixSettings = import ./nix-settings.nix;

  murphHardware = import ./hosts/murph/hardware.nix;
  murphBase = import ./hosts/murph/base.nix;
  murphDisko = import ./hosts/murph/disko.nix;
  murphImpermanence = import ./hosts/murph/impermanence.nix;
  murphSuspendDiagnostics = import ./hosts/murph/suspend-diagnostics.nix;

  caseHardware = import ./hosts/case/hardware.nix;
  caseBase = import ./hosts/case/base.nix;
  caseDisko = import ./hosts/case/disko.nix;
  caseAccess = import ./hosts/case/access.nix;
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
  homeHcloud = import ./home/hcloud.nix;
  homeGit = import ./home/git.nix;
  homeLinux = import ./home/linux.nix;
  homeDarwin = import ./home/darwin.nix;
  homeGnomeDesktop = import ./home/gnome-desktop.nix;
  gnomeDesktop = import ./gnome-desktop.nix;
  homeGpg = import ./home/gpg.nix;
  homePass = import ./home/pass.nix;
  homeClaudeCode = import ./home/claude-code.nix;
  homeCodex = import ./home/codex.nix;
  homeGhostty = import ./home/ghostty.nix;
  homeLocalDirectory = import ./home/local-directory.nix;
  homeMurphImpermanence = import ./home/impermanence/murph.nix;
  homeVlc = import ./home/vlc.nix;
  homeEmacs = import ./home/emacs.nix;
  tailscale = import ./tailscale.nix;
  utahWireless = import ./utah-wireless.nix;
}

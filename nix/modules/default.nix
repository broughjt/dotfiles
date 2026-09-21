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

  kippHardware = import ./hosts/kipp/hardware.nix;
  kippBase = import ./hosts/kipp/base.nix;
  kippAccess = import ./hosts/kipp/access.nix;
  kippDisko = import ./hosts/kipp/disko.nix;
  kippImpermanence = import ./hosts/kipp/impermanence.nix;

  tarsHardware = import ./hosts/tars/hardware.nix;
  tarsBase = import ./hosts/tars/base.nix;
  tarsDisko = import ./hosts/tars/disko.nix;
  tarsZfs = import ./hosts/tars/zfs.nix;
  tarsAccess = import ./hosts/tars/access.nix;

  tars1Easystore = import ./hosts/tars1/easystore.nix;

  diskoModule = disko.nixosModules.disko;
  impermanenceModule = impermanence.nixosModules.impermanence;

  linux = import ./linux.nix;
  localDirectory = import ./local-directory.nix;
  ssh = import ./ssh.nix;
  zram = import ./zram.nix;
  # Overlays are a host concern. With home-manager.useGlobalPkgs the Home
  # Manager modules share the system package set and cannot add their own.
  llmAgents = {
    nixpkgs.overlays = [ llmAgentsOverlay ];
  };
  emacsPackageSet = {
    nixpkgs.overlays = emacsOverlays;
  };
  docker = import ./docker.nix;

  homeAgentDetach = import ./home/agent-detach.nix;
  homeDirectories = import ./home/directories.nix;
  homeFish = import ./home/fish.nix;
  homeGh = import ./home/gh.nix;
  homeHcloud = import ./home/hcloud.nix;
  homeGit = import ./home/git.nix;
  homeLinux = import ./home/linux.nix;
  homeDarwin = import ./home/darwin.nix;
  homeGnomeDesktop = import ./home/gnome-desktop.nix;
  gnomeDesktop = import ./gnome-desktop.nix;
  chromium = import ./chromium.nix;
  homeGpg = import ./home/gpg.nix;
  homePass = import ./home/pass.nix;
  homeClaudeCode = import ./home/claude-code.nix;
  homeChromium = import ./home/chromium.nix;
  homeChromiumImpermanence = import ./home/impermanence/chromium.nix;
  homeCodex = import ./home/codex.nix;
  homeGhostty = import ./home/ghostty.nix;
  homeLocalDirectory = import ./home/local-directory.nix;
  homeKippImpermanence = import ./home/impermanence/kipp.nix;
  homeMurphImpermanence = import ./home/impermanence/murph.nix;
  homeVlc = import ./home/vlc.nix;
  homeEmacs = import ./home/emacs.nix;
  tailscale = import ./tailscale.nix;
  utahWireless = import ./utah-wireless.nix;
}

{
  nix-config,
  llmAgentsOverlay,
}:

{ ... }:

{
  nix.settings = nix-config.nixSettings;
  nixpkgs.overlays = [ llmAgentsOverlay ];
  nixpkgs.config = nix-config.nixpkgsConfig;
}

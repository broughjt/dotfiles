{ nix-config }:

{ ... }:

{
  nix.settings = nix-config.nixSettings;
  nixpkgs.config = nix-config.nixpkgsConfig;
}

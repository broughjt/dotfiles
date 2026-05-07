{
  inputs,
  nixpkgs,
  nixos-raspberrypi,
  nixosModules,
}:

nixos-raspberrypi.lib.nixosSystem {
  inherit nixpkgs;
  specialArgs = inputs;
  modules = [ nixosModules.tarsBase ];
}

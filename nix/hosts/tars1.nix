{
  nixos-raspberrypi,
  home-manager,
  nixosModules,
}:

import ./tars.nix {
  inherit nixos-raspberrypi home-manager nixosModules;

  instance = {
    # Black WD EasyStore
    imports = [
      nixosModules.tars1Easystore
      nixosModules.tars1Backups
    ];

    networking.hostName = "tars1";

    # Needs to be exactly 8 hexadecimal characters, stable for this machine, and
    # distinct from every other tars machine.
    networking.hostId = "7a3f19c2";

    # onn. 64G SD Card
    tars.disks.root = "/dev/disk/by-id/mmc-SD64G_0xda7b8c7a";
  };
}

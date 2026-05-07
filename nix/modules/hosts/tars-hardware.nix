{ nixos-raspberrypi }:

{ lib, ... }:

{
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
  ];

  networking.hostName = "tars";
  networking.useDHCP = lib.mkDefault true;

  boot.loader.raspberry-pi.bootloader = "kernel";
  boot.supportedFilesystems.zfs = lib.mkForce false;

  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-label/NIXOS_SD";
    fsType = lib.mkDefault "ext4";
    options = lib.mkForce [
      "x-initrd.mount"
      "noatime"
    ];
  };

  fileSystems."/boot/firmware" = {
    device = lib.mkDefault "/dev/disk/by-label/FIRMWARE";
    fsType = lib.mkDefault "vfat";
    options = lib.mkDefault [
      "noatime"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=1min"
    ];
  };

  system.stateVersion = "25.11";
}

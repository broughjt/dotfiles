{ pkgs, ... }:

{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs = {
    devNodes = "/dev/disk/by-id";
    # nixos-anywhere exports every pool before it reboots, so the first boot
    # imports zroot cleanly despite the installer's different hostid, and after
    # that the pool only ever belongs to this host. A pool left imported by a
    # recovery session needs `zpool export zroot` there, or `zfs_force=1` on the
    # kernel command line once.
    forceImportRoot = false;
  };

  services.zfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  environment.systemPackages = [ pkgs.zfs ];
}

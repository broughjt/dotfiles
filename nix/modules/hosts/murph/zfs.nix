{
  config,
  pkgs,
  ...
}:

{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs = {
    devNodes = "/dev/disk/by-id";
    # zroot has only ever been imported by this host since the install, so the
    # import needs no force. If a boot ever refuses it, press e in systemd-boot
    # and append zfs_force=1 for that boot.
    forceImportRoot = false;
    requestEncryptionCredentials = [ "zroot/enc" ];
  };

  # Required by ZFS. Must be exactly 8 hexadecimal characters and stable for this host.
  networking.hostId = "49499dc3";

  boot.initrd.systemd.services.rollback-root = {
    description = "Rollback ephemeral ZFS root to a blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-zroot.service" ];
    before = [ "sysroot.mount" ];
    path = [ config.boot.zfs.package ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      zfs rollback -r zroot/enc/local/root@blank
    '';
  };

  fileSystems."/".neededForBoot = true;
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;

  services.zfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  # The com.sun:auto-snapshot=true that disko.nix sets on zroot/enc/safe/persist
  # does nothing on its own; zfstools is what reads it, and it is opt-in, so the
  # ephemeral root, /nix and the Docker dataset are excluded by the false they
  # already carry. Retention stays at the module's defaults until replication to
  # a tars machine exists, because the two ends have to expire snapshots on
  # policies that keep a common ancestor.
  services.zfs.autoSnapshot = {
    enable = true;
    # -k -p are the module's defaults, kept because the option takes one string.
    # --utc so that a daylight-saving shift cannot collide two snapshot names or
    # order one before the snapshot it followed.
    flags = "-k -p --utc";
  };

  environment.systemPackages = with pkgs; [
    zfs
  ];
}

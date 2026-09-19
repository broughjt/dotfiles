{
  config,
  lib,
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

  # No disk swap or hibernation for now. Add a swap device and resume config later
  # if hibernation becomes important.
  swapDevices = lib.mkForce [ ];
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.zfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  # Snapshots and replication are in backup.nix, which uses sanoid rather than
  # services.zfs.autoSnapshot; sanoid's naming is the only one the receiving end
  # can expire. That leaves the com.sun:auto-snapshot properties disko.nix sets
  # on this pool inert, since nothing reads them any more. They are harmless and
  # stay where they are rather than provoke an edit to disko.nix; sanoid takes
  # its dataset list from its own configuration.

  environment.systemPackages = with pkgs; [
    zfs
  ];
}

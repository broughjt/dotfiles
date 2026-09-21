{ config, ... }:

let
  # installTars --disk-key puts the key at the first path on the installer for
  # pool creation; the mount hook below copies it to the second, where the
  # installed system reads it.
  installerKey = "/tmp/easystore.key";
  key = "/var/lib/zfs/easystore.key";
  root = config.disko.rootMountPoint;
in
{
  disko.devices = {
    disk.easystore = {
      type = "disk";
      # The disk's id not the USB-SATA's
      device = "/dev/disk/by-id/ata-WDC_WD50NDZW-11MR8S1_WD-WX52D41FF8E2";
      content = {
        type = "gpt";
        partitions.zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "easystore";
          };
        };
      };
    };

    zpool.easystore = {
      type = "zpool";
      options.ashift = "12";
      rootFsOptions = {
        acltype = "posixacl";
        atime = "off"; # Nothing stored here reads an access time
        relatime = "on";
        compression = "zstd";
        dnodesize = "auto";
        mountpoint = "none";
        normalization = "formD";
        xattr = "sa";
        "com.sun:auto-snapshot" = "false";
      };

      datasets.data = {
        type = "zfs_fs";
        mountpoint = "/srv/easystore";
        # A missing or locked EasyStore should not stop the Pi booting to the
        # point where it can be reached and fixed.
        mountOptions = [ "nofail" ];
        # Encrypted with a key kept on zroot. This protects the EasyStore if it
        # leaves on its own, not the Pi and the drive together. The key is 64
        # hex characters rather than 32 raw bytes so that it can live in the
        # password store as text.
        options = {
          encryption = "aes-256-gcm";
          keyformat = "hex";
          keylocation = "file://${installerKey}";
          # The mountpoint property above would also make `zfs mount -a` claim
          # this dataset, racing the systemd mount unit that disko generates
          # from the same declaration. Whichever loses reports "mountpoint or
          # dataset is busy" and fails; it went unnoticed because the race was
          # won by a few tens of milliseconds until 2026-09-20. noauto leaves
          # the mount unit as the only owner. mount(8) ignores canmount, so the
          # unit still mounts it.
          canmount = "noauto";
        };
        postCreateHook = "zfs set keylocation=file://${key} easystore/data";
        # disko runs this after loading the key and again after mounting the
        # dataset; only the second time is the new root mounted to receive the
        # key. A later `disko --mode mount` finds no key in /tmp and skips it.
        # /var and /var/lib are made first because install -d would give them
        # the leaf's mode.
        postMountHook = ''
          if [ -e ${installerKey} ] && findmnt ${root} >/dev/null; then
            install -d -m 0755 ${root}/var ${root}/var/lib
            install -d -m 0700 ${root}${dirOf key}
            install -m 0400 ${installerKey} ${root}${key}
          fi
        '';
      };
    };
  };

  # Ask for keys by name rather than walking the pool. The default walks every
  # dataset on every pool and prompts for each locked one, and syncoid's
  # raw-send target easystore/backups/murph-persist arrives with
  # keylocation=prompt. That makes zfs-import-easystore.service block forever in
  # systemd-ask-password on a console this machine does not have, holding the
  # /srv/easystore mount job open and with it local-fs.target, so
  # multi-user.target never activates and NetworkManager never starts. The
  # nofail above cannot help: the mount never fails, it never finishes. tars1 is
  # not meant to hold murph's key, so it must never be asked for it.
  boot.zfs.requestEncryptionCredentials = [ "easystore/data" ];

  # Trimming breaks for both the USB stick and the EasyStore
  # USB stick fails with "trim operations are not supported by this device"
  # EasyStore fails with "critical target error ... DISCARD"
  # Observed 2026-09-15
  #
  # Note: Re-enable if switching away from EasyStore
  services.zfs.trim.enable = false;
}

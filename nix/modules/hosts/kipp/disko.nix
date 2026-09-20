{
  # murph's layout without the encryption: kipp has to come back from a power
  # cut with nobody there to type a passphrase.
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/ata-SanDisk_SD9TB8W256G1001_191333800959";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              extraArgs = [
                "-n"
                "ESP"
              ];
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "zroot";
            };
          };
        };
      };
    };

    zpool.zroot = {
      type = "zpool";
      options = {
        ashift = "12";
        autotrim = "on";
      };
      rootFsOptions = {
        acltype = "posixacl";
        atime = "on";
        relatime = "on";
        compression = "zstd";
        dnodesize = "auto";
        mountpoint = "none";
        normalization = "formD";
        xattr = "sa";
      };

      # local is what a reinstall could recreate; safe is what it could not.
      datasets = {
        "local" = {
          type = "zfs_fs";
          options.mountpoint = "none";
        };

        "local/root" = {
          type = "zfs_fs";
          mountpoint = "/";
          postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot/local/root@blank$' || zfs snapshot zroot/local/root@blank";
        };

        "local/nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
        };

        "local/docker" = {
          type = "zfs_fs";
          mountpoint = "/var/lib/docker";
        };

        "safe" = {
          type = "zfs_fs";
          options.mountpoint = "none";
        };

        "safe/persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
        };
      };
    };
  };
}

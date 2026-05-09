{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380";
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
        atime = "off";
        compression = "zstd";
        dnodesize = "auto";
        mountpoint = "none";
        normalization = "formD";
        relatime = "on";
        xattr = "sa";
        "com.sun:auto-snapshot" = "false";
      };

      datasets = {
        "enc" = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            encryption = "aes-256-gcm";
            keyformat = "passphrase";
            keylocation = "prompt";
          };
        };

        "enc/local" = {
          type = "zfs_fs";
          options.mountpoint = "none";
        };

        "enc/local/root" = {
          type = "zfs_fs";
          mountpoint = "/";
          options."com.sun:auto-snapshot" = "false";
          postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot/enc/local/root@blank$' || zfs snapshot zroot/enc/local/root@blank";
        };

        "enc/local/nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options."com.sun:auto-snapshot" = "false";
        };

        "enc/local/docker" = {
          type = "zfs_fs";
          mountpoint = "/var/lib/docker";
          options."com.sun:auto-snapshot" = "false";
        };

        "enc/safe" = {
          type = "zfs_fs";
          options.mountpoint = "none";
        };

        "enc/safe/persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
          options."com.sun:auto-snapshot" = "true";
        };
      };
    };
  };
}

{ config, lib, ... }:

let
  # The firmware partition is written when a generation is installed and read
  # by the firmware before Linux starts. Nothing needs it mounted in between, so
  # mount it on access, as nixos-raspberrypi's demo configuration does.
  firmwareMountOptions = [
    "noatime"
    "noauto"
    "x-systemd.automount"
    "x-systemd.idle-timeout=1min"
  ];
in
{
  options.tars.disks = {
    root = lib.mkOption {
      type = lib.types.str;
      example = "/dev/disk/by-id/usb-USB_SanDisk_3.2Gen1_03022127073025060850-0:0";
      description = ''
        The drive that becomes zroot. Give a /dev/disk/by-id path: the install
        erases whatever this names, and a by-id path is the only spelling that
        stays attached to a particular drive across reboots and reorderings.
      '';
    };
  };

  config.disko.devices = {
    disk.root = {
      type = "disk";
      device = config.tars.disks.root;
      content = {
        type = "gpt";
        partitions = {
          # The Pi 5 firmware reads config.txt, the kernel, and device trees
          # from the first FAT partition. There is no ESP and nothing at /boot:
          # only U-Boot would use one, and the firmware loads the kernel itself.
          FIRMWARE = {
            priority = 1;
            type = "0700";
            attributes = [ 0 ];
            size = "1024M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot/firmware";
              mountOptions = firmwareMountOptions;
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
      # Following murph's zroot except for atime.
      rootFsOptions = {
        acltype = "posixacl";
        # Off, not murph's relatime: root is an SD card, and nothing here reads
        # an access time. Nix has not used atime for garbage-collection ordering
        # by default in years. relatime stays so that turning atime back on
        # gives the sane behaviour rather than a write per read.
        atime = "off";
        relatime = "on";
        compression = "zstd";
        dnodesize = "auto";
        mountpoint = "none";
        normalization = "formD";
        xattr = "sa";
        "com.sun:auto-snapshot" = "false";
      };

      # Unencrypted, so the Pi boots unattended after a power cut.
      datasets = {
        root = {
          type = "zfs_fs";
          mountpoint = "/";
        };
        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
        };
      };
    };
  };
}

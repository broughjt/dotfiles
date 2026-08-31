{ ... }:

{
  # Every Hetzner Cloud instance presents its system disk as /dev/sda. Do not
  # narrow this to a /dev/disk/by-id path: the QEMU serial in those names is
  # per-VM, and one configuration has to serve every `case` VM.
  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        # Somewhere for GRUB to embed core.img when the firmware is legacy
        # BIOS. Unused under UEFI, and one mebibyte either way.
        boot = {
          size = "1M";
          type = "EF02";
          priority = 1;
        };
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}

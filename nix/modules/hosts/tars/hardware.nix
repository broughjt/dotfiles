{ nixos-raspberrypi, ... }:

{
  # nixos-raspberrypi.lib.nixosSystem passes itself in as a special argument,
  # which is what lets a module in this repository import its hardware modules.
  # Not raspberry-pi-5.page-size-16k. The BCM2712 kernel uses 16K pages, and
  # jemalloc breaks under pages larger than it was built for, but nixpkgs
  # already builds jemalloc for 64K pages on aarch64, which is compatible with
  # 16K. The overlay would only save memory, at the cost of changing the hash
  # of everything linked against jemalloc (fish, git, neovim) and so taking it
  # off cache.nixos.org.
  imports = [ nixos-raspberrypi.nixosModules.raspberry-pi-5.base ];

  # The generational bootloader, which the installer image already boots with.
  # Each generation gets its own kernel, initrd, and device trees under
  # nixos/<generation>-default/ on the firmware partition, and config.txt
  # chooses one with os_prefix. The default for a Pi 5, kernelboot, is
  # deprecated and keeps only the current kernel there.
  boot.loader.raspberry-pi.bootloader = "kernel";

  # serial0 is the debug connector by default on a Pi 5. This moves it to GPIO
  # 14/15 (header pins 8/10), so the UART adapter (which is the one I have from
  # EE classes) is wired.
  hardware.raspberry-pi.config.all.base-dt-params.uart0_console = {
    enable = true;
    value = "on";
  };
}

{
  config,
  lib,
  ...
}:

{
  # A ThinkCentre M920s (10SJ): i5-8600, 16G, I219-LM Ethernet, no Wi-Fi card.
  # The module lists are what nixos-generate-config found on it.
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # The BIOS dates from 2019, and LVFS carries this model.
  services.fwupd.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "usbhid"
      "uas"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
    # The firmware is UEFI-only with Secure Boot turned off by hand; see
    # documentation/kipp-install.md. bootctl also writes the removable path,
    # which is what the firmware falls back to should it ever lose the entry
    # canTouchEfiVariables creates, with nobody watching the screen.
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # Nobody is at the menu, so do not wait for them.
    loader.timeout = 1;
  };
}

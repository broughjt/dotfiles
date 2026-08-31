{
  modulesPath,
  pkgs,
  ...
}:

{
  # Hetzner Cloud runs KVM/QEMU. The profile brings in the virtio drivers and
  # disables the firmware and microcode handling a real machine wants.
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];

  # Resizing the instance grows the block device but not the partition table.
  boot.growPartition = true;

  # Hetzner documents legacy BIOS for x86 Cloud instances and UEFI for arm, but
  # newer instance types have been gaining UEFI, so do not depend on either.
  # With a real device and `efiSupport`, install-grub.pl's getEfiTarget returns
  # "both" on x86_64 (BIOS target i386-pc, EFI target x86_64-efi) and installs
  # GRUB twice: to the BIOS boot partition and to the ESP. On aarch64 there is
  # no BIOS target, so the same settings degrade to EFI alone. One bootloader
  # configuration therefore covers both firmwares and both architectures.
  # boot.loader.grub.devices is not set here: disko declares it from the EF02
  # partition in case/disko.nix, so the BIOS install target follows the disk
  # layout rather than being repeated.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    # A cloud VM has no persistent EFI variable store worth writing to, and
    # canTouchEfiVariables must stay false for this to be allowed.
    efiInstallAsRemovable = true;
  };

  # The Hetzner Cloud console's password reset drives the guest agent, which is
  # the recovery path if the VM boots but never reaches the tailnet. The agent
  # shells out to chpasswd, which is not otherwise on its PATH.
  services.qemuGuest.enable = true;
  systemd.services.qemu-guest-agent.path = [ pkgs.shadow ];
}

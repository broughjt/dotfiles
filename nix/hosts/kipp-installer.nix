{
  nixpkgs,
  nixosModules,
}:

# An installer for a machine nobody can see the screen of. It is a disk image
# with a writable ext4 root rather than the stock ISO, which buys two things:
# flashKippInstaller can put Wi-Fi profiles on it without them entering the Nix
# store, and the installer can leave a report on its own stick for when it never
# reaches the network.
nixpkgs.lib.nixosSystem {
  modules = [
    nixosModules.personal
    (
      {
        config,
        lib,
        modulesPath,
        pkgs,
        ...
      }:
      let
        report = pkgs.writeShellApplication {
          name = "kipp-installer-report";
          runtimeInputs = with pkgs; [
            beep
            config.system.build.nixos-generate-config
            coreutils
            dmidecode
            efibootmgr
            findutils
            gnused
            iproute2
            kmod
            mokutil
            networkmanager
            pciutils
            procps
            systemd
            usbutils
            util-linux
          ];
          text = builtins.readFile ../../scripts/kipp-installer-report.sh;
        };
      in
      {
        imports = [
          # nixos-anywhere looks for the VARIANT_ID=installer this sets in
          # /etc/os-release, and installs from the running system instead of
          # kexec'ing into its own. A kexec would drop the Wi-Fi association
          # and the machine would vanish halfway through the install.
          (modulesPath + "/profiles/installation-device.nix")
          # The tools an install needs, and ZFS.
          (modulesPath + "/profiles/base.nix")
          # The initrd cannot be tailored to a machine whose hardware is what
          # we are booting to find out.
          (modulesPath + "/profiles/all-hardware.nix")
          # Declares image.baseName and friends, as nixpkgs' own image modules
          # use them.
          (modulesPath + "/image/file-options.nix")
        ];

        nixpkgs.hostPlatform = "x86_64-linux";
        networking.hostName = "kipp-installer";
        system.stateVersion = config.system.nixos.release;

        # The firmware mode is as unknown as everything else, so GRUB goes in
        # twice, as on `case`: to the BIOS boot partition for legacy firmware,
        # and to the ESP's removable path for UEFI, which is the only path a
        # firmware with no boot entry for this stick will look at. /dev/vda is
        # the image while make-disk-image's VM is installing to it.
        boot.loader.grub = {
          enable = true;
          device = "/dev/vda";
          efiSupport = true;
          efiInstallAsRemovable = true;
        };
        boot.loader.timeout = 1;

        fileSystems."/" = {
          device = "/dev/disk/by-label/${config.image.baseName}";
          fsType = "ext4";
          autoResize = true;
        };
        fileSystems."/boot" = {
          device = "/dev/disk/by-label/ESP";
          fsType = "vfat";
        };
        # The image is only as large as its contents; nixos-anywhere needs room
        # to copy a system closure in.
        boot.growPartition = true;

        image.baseName = "kipp-installer";
        image.extension = "img";
        system.build.image = import (modulesPath + "/../lib/make-disk-image.nix") {
          inherit config lib pkgs;
          inherit (config.image) baseName;
          format = "raw";
          partitionTableType = "hybrid";
          # The default, "nixos", is a label an installed disk might carry too.
          label = config.image.baseName;
          copyChannel = false;
        };
        system.installer.channel.enable = false;
        documentation.nixos.enable = lib.mkForce false;

        # installation-device.nix turns on NetworkManager, which takes DHCP on
        # any wired interface by itself and the Wi-Fi networks
        # flashKippInstaller wrote. The installer is then found as
        # kipp-installer.local: NetworkManager asks resolved to answer mDNS on
        # every connection it brings up.
        hardware.enableRedistributableFirmware = true;
        services.resolved.enable = true;
        networking.networkmanager.connectionConfig."connection.mdns" = 2;
        networking.firewall.allowedUDPPorts = [ 5353 ];

        # The profile leaves root with an empty password, which sshd refuses but
        # which should not be what stands between the LAN and a root shell.
        services.openssh.settings.PasswordAuthentication = false;
        personal.sshAuthorizedKeys = with config.personal.sshKeys; [
          murph
          iphone
          kipp
        ];
        users.users.root.openssh.authorizedKeys.keys = config.personal.sshAuthorizedKeys;

        systemd.services.kipp-installer-report = {
          description = "Write a hardware and network report to the installer stick";
          wantedBy = [ "multi-user.target" ];
          after = [ "NetworkManager.service" ];
          serviceConfig = {
            Type = "exec";
            ExecStart = lib.getExe report;
          };
        };
      }
    )
  ];
}

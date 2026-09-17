{
  nixos-raspberrypi,
  nixosModules,
}:

# Mirrors nixos-raspberrypi's rpi5-installer, so that everything but the image
# assembly comes from its binary cache, and adds a way in from murph.
nixos-raspberrypi.lib.nixosInstaller {
  modules = [
    nixos-raspberrypi.inputs.nixos-images.nixosModules.sdimage-installer
    (
      { lib, modulesPath, ... }:
      {
        # nixos-images imports the generic aarch64 SD image module, which
        # conflicts with the Raspberry Pi one nixosInstaller provides.
        disabledModules = [
          (modulesPath + "/installer/sd-card/sd-image-aarch64-installer.nix")
        ];
        # nixos-images sets this with mkForce.
        image.baseName = lib.mkOverride 40 "tars-installer";
      }
    )
    nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
    nixosModules.personal
    (
      { config, lib, ... }:
      {
        networking.hostName = "tars-installer";

        # The installer has ZFS for the install and no ZFS root of its own;
        # this only silences nixpkgs' warning about the pre-26.11 default.
        boot.zfs.forceImportRoot = false;

        # nixos-images replaces the networking of nixpkgs' installer profile,
        # NetworkManager with wpa_supplicant, by iwd and networkd, and leaves
        # NetworkManager enabled with no Wi-Fi backend. Restore nixpkgs' setup,
        # as tars uses and the login banner's nmtui advice assumes. networkd has
        # to go entirely: once nixpkgs stops defining its default DHCP networks,
        # the mDNS settings nixos-images puts on them leave units with an empty
        # [Match], which would claim every interface.
        networking.wireless.enable = lib.mkOverride 40 true;
        networking.wireless.iwd.enable = lib.mkForce false;
        networking.useNetworkd = lib.mkForce false;
        systemd.network.enable = lib.mkForce false;

        # flashTarsInstaller puts Wi-Fi profiles on the stick, so the installer
        # joins a network on boot; this lets murph find it as
        # tars-installer.local without a serial console. NetworkManager asks
        # resolved to answer mDNS on every connection it brings up.
        services.resolved.enable = true;
        networking.networkmanager.connectionConfig."connection.mdns" = 2;

        users.users.root.openssh.authorizedKeys.keys = config.personal.sshAuthorizedKeys;

        # serial0 is the debug connector by default on a Pi 5. This moves it to
        # GPIO 14/15 (header pins 8/10), where the UART adapter is typically
        # wired.
        hardware.raspberry-pi.config.all.base-dt-params.uart0_console = {
          enable = true;
          value = "on";
        };
      }
    )
  ];
}

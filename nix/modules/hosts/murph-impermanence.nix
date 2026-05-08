{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
in
{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs = {
    devNodes = "/dev/disk/by-id";
    forceImportRoot = false;
    requestEncryptionCredentials = [ "zroot/enc" ];
  };

  # Required by ZFS. Must be exactly 8 hexadecimal characters and stable for this host.
  networking.hostId = "49499dc3";

  boot.initrd.systemd.services.rollback-root = {
    description = "Rollback ephemeral ZFS root to a blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-zroot.service" ];
    before = [ "sysroot.mount" ];
    path = [ config.boot.zfs.package ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      zfs rollback -r zroot/enc/local/root@blank
    '';
  };

  fileSystems."/".neededForBoot = true;
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;

  # No disk swap or hibernation for now. Add a swap device and resume config later
  # if hibernation becomes important.
  swapDevices = lib.mkForce [ ];
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.zfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  systemd.tmpfiles.rules = [
    "d /persist/etc/ssh 0755 root root -"
  ];

  # Keep SSH host keys out of ephemeral /etc without persisting all of /etc/ssh.
  services.openssh.hostKeys = [
    {
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/persist/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  environment.persistence."/persist" = {
    hideMounts = true;

    files = [
      "/etc/machine-id"
      # User/root password hashes. Move to a declarative hashedPasswordFile later
      # if you want passwords managed outside mutable system state.
      "/etc/shadow"
    ];

    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/fprint"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/log"

      # TODO: if enabling tailscale on murph, persist /var/lib/tailscale.
    ];

    users.${user} = {
      directories = [
        "repositories"
        "local"
        "scratch"
        "share"

        ".ssh"
        ".config/gh"
        ".local/share/gnupg"
        ".local/share/keyrings"
        ".mozilla/firefox"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    zfs
  ];
}

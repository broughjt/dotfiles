{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  userGroup = config.users.users.${user}.group;
in
{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs = {
    devNodes = "/dev/disk/by-id";
    forceImportRoot = true;
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
    "d /persist/etc/passwords 0700 root root -"
  ];

  # Keep /etc/machine-id readable at its normal path without requiring users to
  # traverse /persist.  Impermanence bind-mounts the persisted file below; this
  # activation hook removes any generated file or older symlink first so the bind
  # mount can be established.
  system.activationScripts.seedPersistedMachineId = {
    deps = [
      "etc"
      "createPersistentStorageDirs"
    ];
    text = ''
      if [ ! -e /persist/etc/machine-id ] && [ -f /etc/machine-id ]; then
        cp /etc/machine-id /persist/etc/machine-id
        chmod 0444 /persist/etc/machine-id
      fi
      if ! ${pkgs.util-linux}/bin/findmnt --mountpoint /etc/machine-id >/dev/null 2>&1; then
        rm -f /etc/machine-id
      fi
    '';
  };

  # File entries can fall back to symlinks if the persisted file does not exist.
  # Since /persist is intentionally not traversable by normal users, make sure
  # user-visible persisted files exist before impermanence wires them up.
  system.activationScripts.seedPersistedUserFiles = {
    deps = [
      "createPersistentStorageDirs"
      "users"
      "groups"
    ];
    text = ''
      if [ ! -e /persist/home/${user}/.local/share/fish/fish_history ] && [ -f /home/${user}/.local/share/fish/fish_history ]; then
        cp /home/${user}/.local/share/fish/fish_history /persist/home/${user}/.local/share/fish/fish_history
      fi
      touch /persist/home/${user}/.local/share/fish/fish_history
      chown ${user}:${userGroup} /persist/home/${user}/.local/share/fish/fish_history
      chmod 0600 /persist/home/${user}/.local/share/fish/fish_history
      if ! ${pkgs.util-linux}/bin/findmnt --mountpoint /home/${user}/.local/share/fish/fish_history >/dev/null 2>&1; then
        rm -f /home/${user}/.local/share/fish/fish_history
      fi
    '';
  };
  system.activationScripts.persist-files.deps = [
    "seedPersistedMachineId"
    "seedPersistedUserFiles"
  ];

  # Do not let normal user processes write arbitrary data directly under the
  # persistent backing store. Selected state remains available via the bind
  # mounts declared in environment.persistence below.
  system.activationScripts.persistRootPrivate = {
    deps = [ "persist-files" ];
    text = ''
      ${pkgs.util-linux}/bin/findmnt --mountpoint /persist >/dev/null
      chown root:root /persist
      chmod 0700 /persist
    '';
  };

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

        ".pi/agent/sessions"
        ".config/gh"
        ".local/share/gnupg"
        ".local/share/keyrings"
        ".mozilla/firefox"
        ".ssh"
      ];
      files = [
        ".local/share/fish/fish_history"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    zfs
  ];
}

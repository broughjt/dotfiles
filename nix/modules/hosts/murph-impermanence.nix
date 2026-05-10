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

  system.activationScripts.migrateFishHistoryToLocalHacks = {
    deps = [ "createPersistentStorageDirs" ];
    text = ''
      old=/persist/home/${user}/local/share/fish/fish_history
      visible=${config.defaultDirectories.homeDirectory}/local/share/fish/fish_history
      new=/persist/home/${user}/local/hacks/fish/fish_history

      source=
      if [ -e "$old" ]; then
        source=$old
      elif [ -e "$visible" ] && [ ! -L "$visible" ]; then
        source=$visible
      fi

      if [ -n "$source" ] && [ ! -e "$new" ]; then
        install -d -m 0700 -o ${user} -g users "$(dirname "$new")"
        cp -a -- "$source" "$new"
        chown ${user}:users "$new"
        chmod 0600 "$new"
      fi
    '';
  };

  system.activationScripts.persist-files.deps = [
    "seedPersistedMachineId"
    "migrateFishHistoryToLocalHacks"
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
        "scratch"
        "share"

        {
          directory = ".pi";
          mode = "0700";
        }
        "local/config/gh"
        {
          directory = "local/hacks/fish";
          mode = "0700";
        }
        {
          directory = "local/share/gnupg";
          mode = "0700";
        }
        {
          directory = "local/share/keyrings";
          mode = "0700";
        }
        ".mozilla/firefox"
        ".ssh"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    zfs
  ];
}

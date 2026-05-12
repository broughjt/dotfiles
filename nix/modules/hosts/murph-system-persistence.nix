{
  pkgs,
  ...
}:

{
  systemd.tmpfiles.rules = [
    "d /persist/etc/ssh 0755 root root -"
    "d /persist/etc/passwords 0700 root root -"
  ];

  # Keep /etc/machine-id readable at its normal path without requiring users to
  # traverse /persist. Impermanence bind-mounts the persisted file below; this
  # activation hook removes any generated file or older symlink first so the
  # bind mount can be established.
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

  system.activationScripts.persist-files.deps = [ "seedPersistedMachineId" ];

  # Do not let normal user processes write arbitrary data directly under the
  # persistent backing store. Selected state remains available via the bind
  # mounts declared in environment.persistence below.
  system.activationScripts.persistRootPrivate = {
    deps = [
      "persist-files"
      "warnUnexpectedHackState"
    ];
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
  };
}

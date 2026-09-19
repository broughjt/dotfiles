{ config, ... }:

let
  dataset = "zroot/enc/safe/persist";

  # syncoid runs as its own system user and is always invoked with
  # --no-privilege-elevation, so it needs an identity of its own rather than
  # Jackson's. The private half is installed by hand once into the state
  # directory the unit creates, and persisted from there; tars1 carries the
  # public half. Deliberately not generated on the machine: a host that minted
  # its own key would come up offering one tars1 does not authorize, which
  # reads as a broken backup rather than as the setup step it is.
  identity = "/var/lib/syncoid/.ssh/id_ed25519";
in
{
  # sanoid rather than services.zfs.autoSnapshot, whose zfstools names snapshots
  # `zfs-auto-snap_<interval>-<date>`. Neither tool can expire those on tars1:
  # sanoid's getsnaps only admits names matching /^autosnap/, and zfstools'
  # cleanup only considers datasets it finds mounted, which a raw-received
  # dataset with an unavailable key never is. Keeping zfstools here would mean
  # nothing at either end could ever prune what lands on the backup.
  services.sanoid = {
    enable = true;
    # sanoid takes a snapshot when the newest of a type is older than its
    # period, so it must run at least as often as the shortest period it keeps.
    # frequent_period defaults to 15 minutes.
    interval = "*:0/15";
    datasets.${dataset} = {
      autosnap = true;
      autoprune = true;
    }
    // config.zfsRetention.source;
  };

  services.syncoid = {
    enable = true;
    # On the hour. tars1 prunes at half past, so the two passes stay apart.
    interval = "hourly";
    sshKey = identity;
    # Replicate the snapshots sanoid already takes rather than letting syncoid
    # add a parallel set of its own.
    commonArgs = [ "--no-sync-snap" ];

    commands.${dataset} = {
      target = "syncoid@tars1:easystore/backups/murph-persist";
      # Raw. The stream stays encrypted under murph's passphrase for the whole
      # trip and at rest, so tars1 stores ciphertext it holds no key for.
      sendOptions = "w";
      # The receive parent is mountpoint=none and the key is unavailable there
      # in any case; this only states the intent at the point it applies.
      recvOptions = "u";
    };
  };

  # A replication run is not interactive, so tars1's host key has to be known
  # before the first connection rather than accepted at it. This pins the
  # tailnet name, which is what syncoid dials.
  programs.ssh.knownHosts.tars1 = {
    hostNames = [ "tars1" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYWZXY4pbgX8KHaYlDA/Ob7Pk1exQUyzb6HZuIJT4GJ";
  };
}

let
  retention = import ../../zfs-retention.nix;
  dataset = "zroot/enc/safe/persist";
  identity = "/var/lib/syncoid/.ssh/id_ed25519";
in
{
  services.sanoid = {
    enable = true;
    interval = "*:0/15";
    datasets.${dataset} = {
      autosnap = true;
      autoprune = true;
    }
    // retention.source;
  };

  services.syncoid = {
    enable = true;
    # Five past, so the push carries the snapshots sanoid takes on the hour
    # rather than racing them.
    interval = "*:05";
    sshKey = identity;
    # The module's default also grants snapshot and destroy, which only syncoid's
    # own sync snapshots need.
    localSourceAllow = [
      "bookmark"
      "hold"
      "send"
    ];
    commonArgs = [
      # Replicate the snapshots already taken by sanoid rather than creating new
      # ones
      "--no-sync-snap"
      # Without this syncoid passes -F to zfs receive, which tars1 refuses; see
      # the delegation in tars1/backups.nix.
      "--no-rollback"
      # An unforced raw receive must start from the newest snapshot on tars1, so
      # that snapshot has to still exist here at the next push. sanoid takes the
      # frequent one last in each run, and murph keeps those for only two hours
      # of uptime. Leaving them out makes the newest on tars1 an hourly instead.
      "--exclude-snaps=_frequently"
    ];

    commands.${dataset} = {
      target = "syncoid@tars1:easystore/backups/murph-persist";
      # Raw, so tars1 stores ciphertext not plaintext
      sendOptions = "w";
      # Unmounted
      recvOptions = "u";
    };
  };
}

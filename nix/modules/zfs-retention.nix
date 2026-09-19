# sanoid retention for a dataset that one machine snapshots and another
# receives. Not a NixOS module; each end imports it and splices its half into
# services.sanoid.datasets.<name>. The two halves are kept together because
# they only make sense as a pair.
#
# For each period, sanoid prunes a snapshot only when it is older than N periods
# and more than N of that period exist. So N is a floor on both count and age,
# and a laptop that was closed for a week still has its last N afterwards.
#
# Only the source takes snapshots, and sanoid takes a period only when its N is
# above zero. The backup can therefore only accumulate periods the source keeps
# at least one of.
#
# The backup is append-only (see tars1/backups.nix), so each push must start
# from the backup's newest snapshot, and that snapshot must still exist on the
# source. The frequent snapshots are never sent (see murph/backup.nix), which
# makes the backup's newest an hourly. Two consequences. The backup must never
# prune its newest snapshot, so its hourly N stays above zero. And how long
# murph can run without reaching tars1 is set by the source's hourly N: that
# many hours of uptime at least. Past that the push fails, loudly, until the
# backup's unmatched tail is destroyed by hand.
{
  # Short-term undo, because every snapshot pins blocks a small disk could
  # otherwise reuse.
  source = {
    frequently = 8; # 2h of quarter-hours
    hourly = 36;
    daily = 14;
    weekly = 0;
    # Costs up to a month of pinned churn. Exists only to feed the backup's
    # monthlies.
    monthly = 1;
    yearly = 0;
  };

  # The long history.
  backup = {
    frequently = 0; # Never sent
    hourly = 72;
    daily = 30;
    weekly = 0;
    monthly = 12;
    yearly = 0;
  };
}

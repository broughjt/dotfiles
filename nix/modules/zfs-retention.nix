{ config, lib, ... }:

let
  cfg = config.zfsRetention;

  policy = lib.types.attrsOf lib.types.ints.unsigned;

  # Every sanoid period except `frequently`, which the backup end deliberately
  # keeps none of. See the assertion below.
  comparable = [
    "hourly"
    "daily"
    "weekly"
    "monthly"
    "yearly"
  ];
in
{
  options.zfsRetention = {
    source = lib.mkOption {
      type = policy;
      description = ''
        Snapshot counts sanoid keeps on a machine that owns its data. These are
        counts, not ages. A laptop that is closed for a week expires nothing
        while it is off, so a given number covers far more wall-clock time on
        murph than the same number would on a machine that is always up.
      '';
    };

    backup = lib.mkOption {
      type = policy;
      description = ''
        Snapshot counts sanoid keeps on a machine that receives replicas. It
        takes none of its own; every snapshot it holds arrived over the wire
        and expires here on this policy rather than the sender's.
      '';
    };
  };

  config = {
    # One decision written in one place, because neither half means anything
    # without the other. syncoid can only send an incremental when a snapshot
    # exists on both ends; with no snapshot in common the next run is a fresh
    # 48.7G seed, which over murph's wifi is an hour and a half.
    #
    # The source keeps short-term undo and nothing else. murph has 111G free on
    # a 250G NVMe, and every snapshot it holds pins blocks the laptop could
    # otherwise reuse. The backup keeps the long history, where 48.7G against
    # 4.42T means none of these numbers cost anything worth counting.
    zfsRetention.source = lib.mapAttrs (_: lib.mkDefault) {
      frequently = 8; # 2h, so an hourly push always spans the gap since the last
      hourly = 36; # 1.5 days of uptime
      daily = 14;
      weekly = 0;
      monthly = 0;
      yearly = 0;
    };

    zfsRetention.backup = lib.mapAttrs (_: lib.mkDefault) {
      # No sub-hourly history here. The frequent snapshots still travel, as
      # intermediates of the stream that carries the hourly one, and are
      # expired on arrival. Dropping them merges their deltas rather than
      # re-sending anything, so this costs no bandwidth.
      frequently = 0;
      hourly = 72;
      daily = 30;
      weekly = 8;
      monthly = 12;
      yearly = 0;
    };

    assertions = map (period: {
      assertion = (cfg.backup.${period} or 0) >= (cfg.source.${period} or 0);
      message = ''
        zfsRetention.backup.${period} is ${toString (cfg.backup.${period} or 0)},
        below zfsRetention.source.${period} at ${toString (cfg.source.${period} or 0)}.
        The receiving end must not expire a class faster than the sending end,
        or the two can be left with no snapshot in common and the next run
        falls back to a full send.
      '';
    }) comparable;
  };
}

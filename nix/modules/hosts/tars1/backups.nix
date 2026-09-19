{ config, pkgs, ... }:

let
  parent = "easystore/backups";
  dataset = "${parent}/murph-persist";
in
{
  # The account murph's syncoid pushes as, separate from Jackson's so that the
  # delegation below describes exactly what a replication run may do and a key
  # taken off murph does not also carry a login as him.
  users.groups.syncoid = { };
  users.users.syncoid = {
    isSystemUser = true;
    group = "syncoid";
    home = "/var/lib/syncoid";
    createHome = true;
    # sshd needs a usable shell to run the zfs commands syncoid sends over.
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [
      # murph's syncoid identity. Generated there, private half never copied.
      "no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFz7b4Ij+cubosFLsGIg6nXwU3sqWpZ2Kildn2rpChe/ syncoid@murph"
    ];
  };

  # nixpkgs' syncoid module runs `zfs allow` only for datasets local to the
  # machine it runs on, and its own option documentation says permissions on a
  # remote target are the operator's to set. Hence a unit here rather than an
  # option over there.
  #
  # `destroy` is deliberately withheld. Pushing from murph is the wrong
  # direction for resisting a compromise of murph, and withholding destroy is
  # most of what buys that back: murph can add snapshots here and cannot remove
  # any. Expiry is this machine's own decision, taken by the sanoid unit below,
  # which is granted destroy locally and only locally.
  #
  # `mount` is required by ZFS for create and receive even though nothing under
  # this parent is ever mounted.
  systemd.services.zfs-allow-syncoid = {
    description = "Delegate receive on ${parent} to the syncoid account";
    wantedBy = [ "multi-user.target" ];
    after = [ "zfs.target" ];
    path = [ config.boot.zfs.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # No fallback when the EasyStore is absent. easystore/data mounts nofail so
    # the Pi still boots without the drive, and a replication path that quietly
    # degraded to writing somewhere else would be worse than one that fails
    # where it can be seen.
    script = ''
      zfs allow -u syncoid create,mount,receive,rollback ${parent}
    '';
  };

  # Pruning only. Every snapshot under the receive parent arrived from murph,
  # so autosnap stays off: snapshots taken here would not exist on the sending
  # end and would put the two out of step for nothing.
  services.sanoid = {
    enable = true;
    # Half past, clear of murph's hourly push.
    interval = "*:30:00";
    datasets.${dataset} = {
      autosnap = false;
      autoprune = true;
    }
    // config.zfsRetention.backup;
  };
}

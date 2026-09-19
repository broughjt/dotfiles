{ config, pkgs, ... }:

let
  retention = import ../../zfs-retention.nix;
  parent = "easystore/backups";
  dataset = "${parent}/murph-persist";
in
{
  # Dedicated syncoid account
  users.groups.syncoid = { };
  users.users.syncoid = {
    isSystemUser = true;
    group = "syncoid";
    home = "/var/lib/syncoid";
    createHome = true;
    # sshd needs a usable shell to run the zfs commands syncoid sends over.
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [
      # murph's syncoid identity
      "restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFz7b4Ij+cubosFLsGIg6nXwU3sqWpZ2Kildn2rpChe/ syncoid@murph"
    ];
  };

  # Append-only. Plain `receive` would permit `zfs receive -F`, and a forced
  # incremental destroys every snapshot on the target newer than its base, with
  # no `destroy` permission involved. `receive:append` refuses -F, so murph's
  # key can add snapshots here and can never remove one. The price is that an
  # unforced receive needs the newest snapshot here to still exist on murph and
  # to be untouched here; zfs-retention.nix says how that is kept true. If
  # murph outlives its hourlies away from home, the push fails until someone
  # destroys the unmatched tail here as root.
  systemd.services.zfs-allow-syncoid = {
    description = "Delegate append-only receive on ${parent} to the syncoid account";
    wantedBy = [ "multi-user.target" ];
    after = [ "zfs.target" ];
    path = [ config.boot.zfs.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # Delegations live in the pool and `zfs allow` only adds, so clear first
    # or a permission dropped from this list would stay granted.
    script = ''
      zfs unallow -u syncoid ${parent}
      zfs allow -u syncoid create,mount,receive:append ${parent}
    '';
  };

  services.sanoid = {
    enable = true;
    # Half past, clear of murph's push at five past.
    interval = "*:30:00";
    datasets.${dataset} = {
      autosnap = false;
      autoprune = true;
    }
    // retention.backup;
  };
}

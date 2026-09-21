{
  config,
  lib,
  pkgs,
  ...
}:

let
  library = "/srv/easystore/immich";
  postgres = "/srv/easystore/postgres";

  # Children of easystore/data share its encryption root, so the key loaded for
  # it at boot unlocks them too and requestEncryptionCredentials needs no new
  # entry. They are mounted the way easystore.nix mounts their parent, and for
  # the same reasons: nofail so the Pi boots without the drive, and noauto so
  # the mount unit is the only thing that mounts them.
  dataset = mountpoint: options: {
    type = "zfs_fs";
    inherit mountpoint;
    mountOptions = [ "nofail" ];
    options = {
      canmount = "noauto";
    }
    // options;
  };

  # A new dataset's root belongs to root, and Postgres's directory inside its
  # dataset does not exist at all, so a unit of its own makes each service's
  # directory first. It cannot be an ExecStartPre on the service: Postgres's
  # sandbox names its directory and cannot be built without it, even for a
  # command run with +. Nor can it be tmpfiles: a nofail mount is not ordered
  # before local-fs.target, so at boot tmpfiles can run ahead of the mount and
  # act on the bare mountpoint instead.
  directoryFor = service: user: group: path: {
    description = "Create ${path} for ${service}";
    requiredBy = [ "${service}.service" ];
    before = [ "${service}.service" ];
    unitConfig.RequiresMountsFor = path;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe' pkgs.coreutils "install"} -d -m 0700 -o ${user} -g ${group} ${path}";
    };
  };
in
{
  disko.devices.zpool.easystore.datasets = {
    # Large files written once and read whole.
    "data/immich" = dataset library { recordsize = "1M"; };
    # Two Postgres pages to a record. Matching the 8k page exactly gives zstd
    # too little to work with.
    "data/postgres" = dataset postgres { recordsize = "16k"; };
  };

  services.immich = {
    enable = true;
    # Every interface, of which the firewall admits only tailscale0; see
    # tars/access.nix.
    host = "0.0.0.0";
    mediaLocation = library;
  };

  # On the EasyStore rather than the SD card, whose endurance is unmeasured and
  # which has no spare. The Postgres module already requires the mount under
  # dataDir, so with the drive absent Postgres fails to start instead of
  # initializing an empty database on the bare mountpoint. The directory is
  # named for the major version, as the module's default is, so that a
  # pg_upgrade has somewhere to put the new cluster beside the old.
  services.postgresql.dataDir = "${postgres}/${config.services.postgresql.package.psqlSchema}";

  # Likewise for the server, which would otherwise come up against its database
  # with the library missing.
  systemd.services.immich-server.unitConfig.RequiresMountsFor = library;

  systemd.services.immich-library-directory =
    with config.services.immich;
    directoryFor "immich-server" user group library;
  systemd.services.postgresql-data-directory =
    directoryFor "postgresql" "postgres" "postgres"
      config.services.postgresql.dataDir;
}

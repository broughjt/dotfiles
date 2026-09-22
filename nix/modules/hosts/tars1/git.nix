{
  config,
  lib,
  pkgs,
  ...
}:

let
  directory = "/srv/easystore/git";
  inherit (config.personal) userName;
  inherit (config.users.users.${userName}) group;
in
{
  disko.devices.zpool.easystore.datasets."data/git" = {
    type = "zfs_fs";
    mountpoint = directory;
    # So tars1 boots if the EasyStore is not attached
    mountOptions = [ "nofail" ];
    # To not duplicate the mount the mount unit already does
    options.canmount = "noauto";
  };

  systemd.services.easystore-git-directory = {
    description = "Give ${directory} to ${userName}";
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = directory;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe' pkgs.coreutils "install"} -d -m 0755 -o ${userName} -g ${group} ${directory}";
    };
  };
}

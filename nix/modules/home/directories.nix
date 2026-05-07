{ config, lib, ... }:

{
  options =
    let
      homeDirectory = "/home/${config.personal.userName}";
    in
    {
      defaultDirectories.homeDirectory = lib.mkOption {
        type = lib.types.str;
        default = homeDirectory;
      };
      defaultDirectories.repositoriesDirectory = lib.mkOption {
        type = lib.types.str;
        default = "${homeDirectory}/repositories";
      };
      defaultDirectories.localDirectory = lib.mkOption {
        type = lib.types.str;
        default = "${homeDirectory}/local";
      };
      defaultDirectories.scratchDirectory = lib.mkOption {
        type = lib.types.str;
        default = "${homeDirectory}/scratch";
      };
      defaultDirectories.shareDirectory = lib.mkOption {
        type = lib.types.str;
        default = "${homeDirectory}/share";
      };
    };
}

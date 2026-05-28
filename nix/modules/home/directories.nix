{ config, lib, ... }:

{
  options = {
    defaultDirectories.homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.personal.userName}";
    };
    defaultDirectories.repositoriesDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.defaultDirectories.homeDirectory}/repositories";
    };
    defaultDirectories.localDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.defaultDirectories.homeDirectory}/local";
    };
    defaultDirectories.scratchDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.defaultDirectories.homeDirectory}/scratch";
    };
    defaultDirectories.shareDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.defaultDirectories.homeDirectory}/share";
    };
  };
}

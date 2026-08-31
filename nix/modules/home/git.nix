{ config, lib, ... }:

{
  programs.git = {
    enable = true;

    signing = lib.mkIf (config.personal.signingKey != null) {
      key = config.personal.signingKey;
      signByDefault = config.programs.gpg.enable;
    };

    settings = {
      user = {
        name = config.personal.fullName;
        email = config.personal.email;
      };
      # "Are the worker threads going to unionize?"
      init.defaultBranch = "main";
    };
  };
}

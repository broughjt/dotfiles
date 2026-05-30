{ config, ... }:

{
  programs.git = {
    enable = true;
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

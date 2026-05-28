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

  # Keep global Git config fully declarative. Home Manager still renders the
  # config into the Nix store, but Git reads it directly from there instead of
  # through a symlink at $XDG_CONFIG_HOME/git/config.
  xdg.configFile."git/config".enable = false;
  home.sessionVariables.GIT_CONFIG_GLOBAL = "${config.xdg.configFile."git/config".source}";
}

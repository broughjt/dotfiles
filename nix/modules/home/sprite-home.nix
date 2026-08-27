{ config, pkgs, ... }:

{
  # Sprites have neither systemd nor a need for Home Manager to create its
  # default XDG keep files. Keep the first generation's ownership surface to
  # the explicit probe below.
  systemd.user.enable = false;
  xdg.enable = false;

  home = {
    username = "sprite";
    homeDirectory = "/home/sprite";
    stateVersion = "26.05";

    # Prove that a standalone Home Manager generation can take ownership of a
    # path reached by sprite exec's fixed PATH. Replace this probe with the
    # declarative Claude Code wrapper once activation is verified end to end.
    file = {
      # Home Manager declares these empty marker files even with xdg.enable
      # disabled. They are unnecessary on a sprite and would expand this
      # probe's ownership beyond its one intended path.
      "${config.xdg.cacheHome}/.keep".enable = false;
      "${config.xdg.stateHome}/.keep".enable = false;

      ".local/bin/hm-probe".source = pkgs.writeShellScript "hm-probe" ''
        echo "Home Manager generation is active"
      '';
    };
  };
}

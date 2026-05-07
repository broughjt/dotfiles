{ config, pkgs, ... }:

{
  home-manager.users.${config.personal.userName} = {
    home.packages = with pkgs; [ pinentry-gnome3 ];

    services.ssh-agent.enable = pkgs.stdenv.isLinux;

    programs.gpg = {
      enable = true;
      homedir =
        let
          xdgDataHome = config.home-manager.users.${config.personal.userName}.xdg.dataHome;
        in
        "${xdgDataHome}/gnupg";
    };
    services.gpg-agent = {
      enable = pkgs.stdenv.isLinux;
      pinentry.package = pkgs.pinentry-gnome3;
      # https://superuser.com/questions/624343/keep-gnupg-credentials-cached-for-entire-user-session
      defaultCacheTtl = 34560000;
      maxCacheTtl = 34560000;
    };
  };
}

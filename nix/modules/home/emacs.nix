{
  emacsOverlays,
  emacsHome,
}:

{ config, ... }:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
  emacsStateDirectory = "${localDirectory}/state/emacs";
  emacsCacheDirectory = "${localDirectory}/cache/emacs";
in
{
  nixpkgs.overlays = emacsOverlays;

  # Pre-create the ephemeral state/cache subdirectories Emacs writes to. The
  # parent ~/local/{state,cache} dirs are already declared in linux.nix.
  systemd.tmpfiles.rules = [
    "d ${emacsStateDirectory} 0700 ${user} users -"
    "d ${emacsStateDirectory}/backups 0700 ${user} users -"
    "d ${emacsStateDirectory}/auto-saves 0700 ${user} users -"
    "d ${emacsStateDirectory}/auto-save-list 0700 ${user} users -"
    "d ${emacsStateDirectory}/transient 0700 ${user} users -"
    "d ${emacsCacheDirectory} 0700 ${user} users -"
    "d ${emacsCacheDirectory}/eln-cache 0700 ${user} users -"
    "d ${emacsCacheDirectory}/lsp 0700 ${user} users -"
  ];

  home-manager.users.${user}.imports = [ emacsHome ];
}

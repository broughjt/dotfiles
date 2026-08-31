{ config, lib, ... }:

let
  toHomeRelativePath = import ../../lib/to-home-relative-path.nix { inherit config lib; };
  localDirectory = config.defaultDirectories.localDirectory;
  sshPublicKeyPath = toHomeRelativePath "${localDirectory}/secrets/ssh/id_ed25519.pub";
in
{
  # Collect the XDG base directories into one ~/local tree. linux-base.nix
  # states the same layout for PAM and the systemd user manager, which
  # evaluate outside Home Manager.
  xdg = {
    binHome = "${localDirectory}/bin";
    cacheHome = "${localDirectory}/cache";
    configHome = "${localDirectory}/config";
    dataHome = "${localDirectory}/share";
    stateHome = "${localDirectory}/state";
  };

  # Only the private key is persisted state; materialise the derivable public
  # half beside it.
  home.file.${sshPublicKeyPath} = {
    force = true;
    text = config.personal.sshPublicKey + "\n";
  };
}

{ config, ... }:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
in
{
  # OpenSSH has no XDG-aware user configuration path, and Home Manager always
  # writes ~/.ssh/config. Keep the personal user's store-backed client policy in
  # the system configuration instead of creating a top-level home dotfile.
  programs.ssh.extraConfig = ''
    Match localuser ${user}
      AddKeysToAgent yes
      IdentityFile ${localDirectory}/secrets/ssh/id_ed25519
      UserKnownHostsFile ${localDirectory}/hacks/ssh/known_hosts/known_hosts
  '';
}

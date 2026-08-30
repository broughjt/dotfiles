{
  config,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
in
{
  systemd.tmpfiles.rules = [
    # Impermanence creates persistence parents at 0755. Everything under the
    # secrets tree is already 0700, but keep the tree itself closed too.
    "d ${localDirectory}/secrets 0700 ${user} users -"

    # GnuPG: only durable subcomponents are persisted. GNUPGHOME itself is
    # ephemeral and only holds these symlinks plus throwaway state
    # (random_seed, locks, sockets, crls.d). private-keys-v1.d and
    # openpgp-revocs.d are symlinked into the persisted secrets tree.
    "d ${localDirectory}/secrets/gnupg/private-keys-v1.d 0700 ${user} users -"
    "d ${localDirectory}/secrets/gnupg/openpgp-revocs.d 0700 ${user} users -"
    "d ${localDirectory}/share/gnupg 0700 ${user} users -"
    "L+ ${localDirectory}/share/gnupg/private-keys-v1.d - - - - ${localDirectory}/secrets/gnupg/private-keys-v1.d"
    "L+ ${localDirectory}/share/gnupg/openpgp-revocs.d - - - - ${localDirectory}/secrets/gnupg/openpgp-revocs.d"
  ];
}

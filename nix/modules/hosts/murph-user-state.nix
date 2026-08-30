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
  ];
}

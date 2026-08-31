{ config, lib, ... }:

let
  user = config.personal.userName;
  cfg = config.ssh;
  clientPolicy = [
    "AddKeysToAgent yes"
  ]
  ++ lib.optional (cfg.identityFile != null) "IdentityFile ${cfg.identityFile}"
  ++ lib.optional (cfg.knownHostsFile != null) "UserKnownHostsFile ${cfg.knownHostsFile}";
in
{
  options.ssh.identityFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = ''
      Private key this machine offers for outbound connections. When null,
      OpenSSH reads its own defaults under ~/.ssh, which is the right answer on
      a host that has not moved its home directory layout elsewhere.
    '';
  };

  options.ssh.knownHostsFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = ''
      File recording accepted host keys. When null, OpenSSH uses
      ~/.ssh/known_hosts. A host that keeps the home directory ephemeral points
      this somewhere durable; because impermanence bind-mounts directories
      rather than files, such a path is usually a file inside a directory whose
      only member it is.
    '';
  };

  config = {
    # OpenSSH has no XDG-aware user configuration path, and Home Manager always
    # writes ~/.ssh/config. Keep the personal user's store-backed client policy in
    # the system configuration instead of creating a top-level home dotfile.
    programs.ssh.extraConfig = ''
      Match localuser ${user}
    ''
    + lib.concatMapStrings (line: "  ${line}\n") clientPolicy;
  };
}

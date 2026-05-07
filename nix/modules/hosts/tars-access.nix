{ config, ... }:

{
  users.users.${config.personal.userName}.openssh.authorizedKeys.keys = [
    config.personal.sshPublicKey
  ];
  users.users.root.openssh.authorizedKeys.keys = [ config.personal.sshPublicKey ];

  security.sudo.wheelNeedsPassword = false;
}

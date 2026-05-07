{ lib, ... }:

{
  options.personal = lib.mkOption {
    type = lib.types.attrs;
    default = {
      userName = "jackson";
      fullName = "Jackson Brough";
      email = "jacksontbrough@gmail.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGwFAXp70zd8VHaNEmQ+txSDFCZENuY4yNReGMVyVM61 jacksontbrough@gmail.com";
    };
  };
}

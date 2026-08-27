{ lib, ... }:

{
  options = {
    personal.userName = lib.mkOption {
      type = lib.types.str;
      default = "jackson";
    };
    personal.fullName = lib.mkOption {
      type = lib.types.str;
      default = "Jackson Brough";
    };
    personal.email = lib.mkOption {
      type = lib.types.str;
      default = "jacksontbrough@gmail.com";
    };
    personal.utahUnid = lib.mkOption {
      type = lib.types.str;
      default = "u1242965";
    };
    personal.sshPublicKey = lib.mkOption {
      type = lib.types.str;
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGwFAXp70zd8VHaNEmQ+txSDFCZENuY4yNReGMVyVM61 jacksontbrough@gmail.com";
    };
  };
}

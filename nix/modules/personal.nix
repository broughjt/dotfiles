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
    personal.signingKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "1BA5F1335AB45105";
    };
    personal.sshKeys = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        murph = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGwFAXp70zd8VHaNEmQ+txSDFCZENuY4yNReGMVyVM61 jacksontbrough@gmail.com";
        kipp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHrwcBYwvkt7fpyYoOp6UHxndoL+OgYfZNH0bP6mcesp jackson@kipp";
        iphone = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINqC3xJ4SpYtp8RXGzah3lpNW4Ajz2WA4aSrW5oRxDKW jackson@iphone";
        sandia = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7nCb5NzPd5XpYVk/4g07v4E4WtpikAjJIGKJpsVWeP jtbroug@sandia.gov";
      };
      description = ''
        User keys by host. Host configurations specify which one they
        own with `sshPublicKey` and which ones may log in with `sshAuthorizedKeys`.
      '';
    };
    personal.sshHostKeys = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        murph = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJJ5wH1Ko+Y9NVhMEwvS830LypRo43elcsrlB29o9QeZ";
        kipp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICOM7Moy8oT0XT1UMoTF0rbmCU7O1BvL0E+r+eeD0+66";
        tars1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYWZXY4pbgX8KHaYlDA/Ob7Pk1exQUyzb6HZuIJT4GJ";
      };
      description = ''
        Host keys by host.
      '';
    };
    personal.sshPublicKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        This machine's outbound SSH identity, or null on a machine with no
        private key.
      '';
    };
    personal.sshAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        List of public keys allowed to log in as this user.
      '';
    };
  };
}

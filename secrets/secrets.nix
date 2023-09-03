let
  kenobi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBndIK51b/o6aSjuTdoa8emnpCRg0s5y68oXAFR66D4/ jacksontbrough@gmail.com";
  linode1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJW41FXloY8w4tjYHbnfsopvpc8USCoSDsRKlInYbJkh root@linode1";
in
{
  "share1-auth-key1.age".publicKeys = [ kenobi ];
  "auth-key-linode1.age".publicKeys = [ kenobi linode1 ];
  "linode1-password.age".publicKeys = [ kenobi linode1 ];
  "wireless.age".publicKeys = [ kenobi ];
}

let
  kenobi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBndIK51b/o6aSjuTdoa8emnpCRg0s5y68oXAFR66D4/ jacksontbrough@gmail.com";
in
{
  "share1-auth-key1.age".publicKeys = [ kenobi ];
  "wireless.age".publicKeys = [ kenobi ];
}

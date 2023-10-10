let
  kenobi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBndIK51b/o6aSjuTdoa8emnpCRg0s5y68oXAFR66D4/ jacksontbrough@gmail.com";
  share1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPALAd6ycOmMNNcoN52p6LyGctpW//2jrSDisc6I7qB6 root@share1";
in
{
  "share1-auth-key1.age".publicKeys = [ kenobi share1 ];
  "wireless.age".publicKeys = [ kenobi share1 ];
}

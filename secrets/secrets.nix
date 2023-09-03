let
  kenobi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBndIK51b/o6aSjuTdoa8emnpCRg0s5y68oXAFR66D4/ jacksontbrough@gmail.com";
  # linode1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILF66MeoetuuV9j4kMEYgsCNcE1b4BOGxX8gIhc+oVUA root@linode1";
  # linode1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINT4VbFNg0rrV/5eBQPLSGSwKstkCPdt+/iptFDQ8NG4 root@linode1";
  linode1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMlN40Eg1sbl3c1C5Jw1BtTtKSbX8CMvpMmszGJyxH2j root@nixos";
in
{
  "share1-auth-key1.age".publicKeys = [ kenobi ];
  "auth-key-linode1.age".publicKeys = [ kenobi linode1 ];
  "linode1-password.age".publicKeys = [ kenobi linode1 ];
  "wireless.age".publicKeys = [ kenobi ];
}

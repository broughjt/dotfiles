let
  jackson = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICv+kva6ORZ2Z9FZNi8ufzzYPQKzy1WvhAYDQt4kEiFU";

  share1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJDyIr/FSz1cJdcoW69R+NrWzwGK/+3gJpqD1t8L2zE";
in
{
  "share1-auth-key1.age".publicKeys = [ share1 ];
}

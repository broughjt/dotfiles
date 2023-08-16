let
  jackson = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICv+kva6ORZ2Z9FZNi8ufzzYPQKzy1WvhAYDQt4kEiFU";

  share1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMQmoxow4kKpKqJos6mwz17YdeIxCRL7SzUlS9XUfcHQ";
in
{
  "share1-auth-key1.age".publicKeys = [ jackson share1 ];
}

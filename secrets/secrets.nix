let
  jackson = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGwFAXp70zd8VHaNEmQ+txSDFCZENuY4yNReGMVyVM61 jacksontbrough@gmail.com";
  workMac = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7nCb5NzPd5XpYVk/4g07v4E4WtpikAjJIGKJpsVWeP";
  users = [
    jackson
    workMac
  ];
in
{
  "exa-api-key.age".publicKeys = users;
  "context7-api-key.age".publicKeys = users;
}

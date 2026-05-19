{ vaultixInput }:

{ config, lib, ... }:

let
  user = config.personal.userName;
  group = "users";
  secretsDirectory = ../../../secrets;
  exaApiKeySecret = secretsDirectory + "/exa-api-key.age";
  context7ApiKeySecret = secretsDirectory + "/context7-api-key.age";
in
{
  imports = [ vaultixInput.nixosModules.default ];

  # Vaultix requires either systemd.sysusers or services.userborn. This config has a
  # normal user, so use userborn rather than systemd.sysusers.
  services.userborn.enable = true;

  vaultix.settings.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJJ5wH1Ko+Y9NVhMEwvS830LypRo43elcsrlB29o9QeZ root@murph";

  vaultix.secrets = {
    exaApiKey.file = exaApiKeySecret;
    context7ApiKey.file = context7ApiKeySecret;
  };

  vaultix.templates.pi-web-minimal-env = {
    name = "pi-web-minimal.env";
    owner = user;
    inherit group;
    mode = "0600";
    content = ''
      export EXA_API_KEY=${lib.escapeShellArg config.vaultix.placeholder.exaApiKey}
      export CONTEXT7_API_KEY=${lib.escapeShellArg config.vaultix.placeholder.context7ApiKey}
    '';
  };
}

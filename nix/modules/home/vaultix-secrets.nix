{ vaultixInput }:

{ config, lib, ... }:

let
  user = config.personal.userName;
  group = "users";
  homeDirectory = config.defaultDirectories.homeDirectory;
  secretsDirectory = ../../../secrets;
  exaApiKeySecret = secretsDirectory + "/exa-api-key.age";
  context7ApiKeySecret = secretsDirectory + "/context7-api-key.age";
in
{
  imports = [ vaultixInput.nixosModules.default ];

  # Vaultix requires either systemd.sysusers or services.userborn. This config has a
  # normal user, so use userborn rather than systemd.sysusers.
  services.userborn.enable = true;

  vaultix.settings.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJaEBK0rIuwE7GqwgeWKA/DvBxIXOcAMDhiORaK9OSf root@murph";

  vaultix.secrets = {
    exaApiKey.file = exaApiKeySecret;
    context7ApiKey.file = context7ApiKeySecret;
  };

  vaultix.templates.pi-web-search-json = {
    name = "pi-web-search.json";
    owner = user;
    inherit group;
    mode = "0600";
    content = builtins.toJSON {
      provider = "auto";
      workflow = "none";
      allowBrowserCookies = false;
      exaApiKey = config.vaultix.placeholder.exaApiKey;
      context7ApiKey = config.vaultix.placeholder.context7ApiKey;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${homeDirectory}/.pi 0700 ${user} ${group} -"
    "L+ ${homeDirectory}/.pi/web-search.json - - - - ${config.vaultix.templates.pi-web-search-json.path}"
  ];
}

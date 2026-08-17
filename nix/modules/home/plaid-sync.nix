{ agenixHome }:

{
  config,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
  secretsDirectory = ../../../secrets;

  plaidConfigDir = "${localDirectory}/config/plaid-sync";
  plaidSecretFile = "${plaidConfigDir}/secret";
  plaidStateDir = "${localDirectory}/state/plaid-sync";
  plaidDataDir = "${localDirectory}/share/plaid-sync";

  plaidClientId = "6a834b38424be4000d63a4fa";

  plaidSync = pkgs.writeShellApplication {
    name = "plaid-sync";
    runtimeInputs = [
      (pkgs.python3.withPackages (pythonPackages: [
        pythonPackages.plaid-python
        pythonPackages.platformdirs
        pythonPackages.python-dotenv
      ]))
    ];
    text = ''
      export PLAID_CLIENT_ID=${plaidClientId}
      export PLAID_SECRET_FILE=${plaidSecretFile}
      export PLAID_ENV=production
      exec python3 ${../../../scripts/plaid-sync.py} "$@"
    '';
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${plaidConfigDir} 0700 ${user} users - -"
    "d ${plaidStateDir} 0700 ${user} users - -"
    "d ${plaidDataDir} 0755 ${user} users - -"
  ];

  home-manager.users.${user} = {
    imports = [ agenixHome ];

    age = {
      identityPaths = [ "${localDirectory}/secrets/ssh/id_ed25519" ];

      secrets.plaidSecret = {
        file = secretsDirectory + "/plaid-secret.age";
        path = plaidSecretFile;
      };
    };

    home.packages = [ plaidSync ];

    systemd.user.services.plaid-sync = {
      Unit.Description = "Pull bank transactions from Plaid";
      Service = {
        Type = "oneshot";
        ExecStart = "${plaidSync}/bin/plaid-sync sync";
      };
    };

    systemd.user.timers.plaid-sync = {
      Unit.Description = "Scheduled Plaid transaction pull";
      Timer = {
        OnCalendar = "*-*-* 07,19:00:00";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}

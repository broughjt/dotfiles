{ piWebMinimalPackage }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  uid = toString config.users.users.${user}.uid;
  homeDirectory = config.defaultDirectories.homeDirectory;
  localDirectory = config.defaultDirectories.localDirectory;

  oldPiAgentDir = "${homeDirectory}/.pi/agent";
  piAgentDir = "${localDirectory}/share/pi/agent";
  piSessionDir = "${localDirectory}/state/pi/sessions";
  piSettingsDir = "${localDirectory}/hacks/pi/settings";
  piSettingsFile = "${piSettingsDir}/settings.json";
  piAuthDir = "${localDirectory}/secrets/pi/auth";
  piAuthFile = "${piAuthDir}/auth.json";
  piPackagesDir = "${piAgentDir}/packages";
  piWebMinimal = piWebMinimalPackage pkgs;
  piWebMinimalEnvFile = "/run/vaultix/pi-web-minimal.env";

  piEnvironment = {
    PI_CODING_AGENT_DIR = piAgentDir;
    PI_CODING_AGENT_SESSION_DIR = piSessionDir;
  };

  seededSettings = pkgs.writeText "pi-settings.json" (
    builtins.toJSON {
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.5";
      defaultThinkingLevel = "high";
      enableInstallTelemetry = false;
      packages = [ "packages/pi-web-minimal" ];
    }
  );

  piPackage = pkgs.writeShellScriptBin "pi" ''
    set -euo pipefail

    export PI_CODING_AGENT_DIR=${lib.escapeShellArg piAgentDir}
    export PI_CODING_AGENT_SESSION_DIR=${lib.escapeShellArg piSessionDir}

    if [ -r ${lib.escapeShellArg piWebMinimalEnvFile} ]; then
      . ${lib.escapeShellArg piWebMinimalEnvFile}
    fi

    exec ${pkgs.llm-agents.pi}/bin/pi "$@"
  '';
in
{
  systemd.services."user@${uid}" = {
    overrideStrategy = "asDropin";
    environment = piEnvironment;
  };

  systemd.services."home-manager-${user}".environment = piEnvironment;

  # Pi's core state is not XDG-native, so keep the runtime agent directory
  # ephemeral and link only the chosen durable pieces into it. Known possible
  # future state to classify if it appears: models.json, keybindings.json,
  # SYSTEM.md/APPEND_SYSTEM.md, extensions/, skills/, prompts/, themes/, git/,
  # npm/, bin/fd, bin/rg, pi-debug.log, project-local .pi/, and arbitrary
  # third-party extension state.
  system.activationScripts.setupPiCodingAgent = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piAgentDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piPackagesDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSettingsDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piAuthDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSessionDir}

      if [ ! -e ${lib.escapeShellArg piSettingsFile} ]; then
        install -m 0600 -o ${user} -g users ${seededSettings} ${lib.escapeShellArg piSettingsFile}
      fi

      if [ ! -e ${lib.escapeShellArg piAuthFile} ] && [ -e ${lib.escapeShellArg "${oldPiAgentDir}/auth.json"} ]; then
        install -m 0600 -o ${user} -g users ${lib.escapeShellArg "${oldPiAgentDir}/auth.json"} ${lib.escapeShellArg piAuthFile}
      fi

      if [ -d ${lib.escapeShellArg "${oldPiAgentDir}/sessions"} ] \
          && [ -z "$(find ${lib.escapeShellArg piSessionDir} -mindepth 1 -print -quit)" ]; then
        cp -a ${lib.escapeShellArg "${oldPiAgentDir}/sessions/."} ${lib.escapeShellArg piSessionDir}/
        chown -R ${user}:users ${lib.escapeShellArg piSessionDir}
      fi

      if [ ! -e ${lib.escapeShellArg piAuthFile} ]; then
        printf '{}\n' > ${lib.escapeShellArg piAuthFile}
        chown ${user}:users ${lib.escapeShellArg piAuthFile}
        chmod 0600 ${lib.escapeShellArg piAuthFile}
      fi

      ln -sfn ${../../../pi/AGENTS.md} ${lib.escapeShellArg "${piAgentDir}/AGENTS.md"}
      ln -sfn ${lib.escapeShellArg piSettingsFile} ${lib.escapeShellArg "${piAgentDir}/settings.json"}
      ln -sfn ${lib.escapeShellArg piAuthFile} ${lib.escapeShellArg "${piAgentDir}/auth.json"}
      ln -sfn ${piWebMinimal} ${lib.escapeShellArg "${piPackagesDir}/pi-web-minimal"}
      chown -h ${user}:users \
        ${lib.escapeShellArg "${piAgentDir}/AGENTS.md"} \
        ${lib.escapeShellArg "${piAgentDir}/settings.json"} \
        ${lib.escapeShellArg "${piAgentDir}/auth.json"} \
        ${lib.escapeShellArg "${piPackagesDir}/pi-web-minimal"}
    '';
  };

  home-manager.users.${user} = {
    home.packages = [ piPackage ];
    home.sessionVariables = piEnvironment;
  };
}

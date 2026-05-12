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
  localDirectory = config.defaultDirectories.localDirectory;

  piShareDir = "${localDirectory}/share/pi";
  piAgentDir = "${piShareDir}/agent";
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
  # ephemeral and link only the chosen durable pieces into it. A small
  # activation script remains so a switch repairs directory ownership before
  # the next boot's tmpfiles run.
  # Known possible future state to classify if it appears: models.json,
  # keybindings.json, SYSTEM.md/APPEND_SYSTEM.md, extensions/, skills/,
  # prompts/, themes/, git/,
  # npm/, bin/fd, bin/rg, pi-debug.log, project-local .pi/, and arbitrary
  # third-party extension state.
  system.activationScripts.migratePiCodingAgent = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piShareDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piAgentDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piPackagesDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSettingsDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piAuthDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSessionDir}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${piShareDir} 0755 ${user} users -"
    "d ${piAgentDir} 0700 ${user} users -"
    "d ${piPackagesDir} 0755 ${user} users -"
    "d ${piSettingsDir} 0700 ${user} users -"
    "C ${piSettingsFile} 0600 ${user} users - ${seededSettings}"
    "d ${piAuthDir} 0700 ${user} users -"
    "f ${piAuthFile} 0600 ${user} users -"
    "d ${piSessionDir} 0700 ${user} users -"
    "L+ ${piAgentDir}/AGENTS.md - - - - ${../../../pi/AGENTS.md}"
    "L+ ${piAgentDir}/settings.json - - - - ${piSettingsFile}"
    "L+ ${piAgentDir}/auth.json - - - - ${piAuthFile}"
    "L+ ${piPackagesDir}/pi-web-minimal - - - - ${piWebMinimal}"
  ];

  home-manager.users.${user} = {
    home.packages = [ piPackage ];
    home.sessionVariables = piEnvironment;
  };
}

{
  piWebMinimalPackage,
  piMcpAdapterPackage,
  todoistCliOverlay,
}:

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
  piStateDir = "${localDirectory}/state/pi/mcp";
  piSettingsDir = "${localDirectory}/hacks/pi/settings";
  piSettingsFile = "${piSettingsDir}/settings.json";
  piMcpConfigDir = "${localDirectory}/secrets/pi/mcp";
  piMcpConfigFile = "${piMcpConfigDir}/mcp.json";
  piAuthDir = "${localDirectory}/secrets/pi/auth";
  piAuthFile = "${piAuthDir}/auth.json";
  piMcpOAuthDir = "${localDirectory}/secrets/pi/mcp-oauth";
  piPackagesDir = "${piAgentDir}/packages";
  piSkillsDir = "${piAgentDir}/skills";
  piWebMinimal = piWebMinimalPackage pkgs;
  piMcpAdapter = piMcpAdapterPackage pkgs;
  todoistCliPiSkill = pkgs.todoist-cli-pi-skill;
  piWebMinimalEnvFile = "/run/vaultix/pi-web-minimal.env";
  piMcpCacheFile = "${piStateDir}/mcp-cache.json";
  piMcpOnboardingFile = "${piStateDir}/mcp-onboarding.json";

  piEnvironment = {
    PI_CODING_AGENT_DIR = piAgentDir;
    PI_MCP_CONFIG = piMcpConfigFile;
    PI_MCP_CACHE = piMcpCacheFile;
    PI_MCP_ONBOARDING_STATE = piMcpOnboardingFile;
    MCP_OAUTH_DIR = piMcpOAuthDir;
  };

  seededSettings = pkgs.writeText "pi-settings.json" (
    builtins.toJSON {
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.5";
      defaultThinkingLevel = "high";
      enableInstallTelemetry = false;
      packages = [
        "packages/pi-web-minimal"
      ];
    }
  );

  piPackage = pkgs.writeShellScriptBin "pi" ''
    set -euo pipefail

    export PI_CODING_AGENT_DIR=${lib.escapeShellArg piAgentDir}
    export PI_MCP_CONFIG=${lib.escapeShellArg piMcpConfigFile}
    export PI_MCP_CACHE=${lib.escapeShellArg piMcpCacheFile}
    export PI_MCP_ONBOARDING_STATE=${lib.escapeShellArg piMcpOnboardingFile}
    export MCP_OAUTH_DIR=${lib.escapeShellArg piMcpOAuthDir}

    if [ -r ${lib.escapeShellArg piWebMinimalEnvFile} ]; then
      . ${lib.escapeShellArg piWebMinimalEnvFile}
    fi

    exec ${pkgs.llm-agents.pi}/bin/pi "$@"
  '';

  piMcpAdapterCli = pkgs.writeShellScriptBin "pi-mcp-adapter" ''
    set -euo pipefail

    export PI_CODING_AGENT_DIR=${lib.escapeShellArg piAgentDir}
    export PI_MCP_CONFIG=${lib.escapeShellArg piMcpConfigFile}
    export PI_MCP_CACHE=${lib.escapeShellArg piMcpCacheFile}
    export PI_MCP_ONBOARDING_STATE=${lib.escapeShellArg piMcpOnboardingFile}
    export MCP_OAUTH_DIR=${lib.escapeShellArg piMcpOAuthDir}

    exec ${pkgs.nodejs}/bin/node ${piMcpAdapter}/cli.js "$@"
  '';
in
{
  nixpkgs.overlays = [ todoistCliOverlay ];

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
  # keybindings.json, SYSTEM.md/APPEND_SYSTEM.md, extensions/, other skills/,
  # prompts/, themes/, git/,
  # npm/, bin/fd, bin/rg, pi-debug.log, project-local .pi/, and arbitrary
  # third-party extension state.
  system.activationScripts.migratePiCodingAgent = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piShareDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piAgentDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piPackagesDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piSkillsDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSettingsDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piMcpConfigDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piAuthDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piMcpOAuthDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSessionDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piStateDir}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${piShareDir} 0755 ${user} users -"
    "d ${piAgentDir} 0700 ${user} users -"
    "d ${piPackagesDir} 0755 ${user} users -"
    "d ${piSkillsDir} 0755 ${user} users -"
    "d ${piSettingsDir} 0700 ${user} users -"
    "C ${piSettingsFile} 0600 ${user} users - ${seededSettings}"
    "d ${piMcpConfigDir} 0700 ${user} users -"
    "d ${piAuthDir} 0700 ${user} users -"
    "f ${piAuthFile} 0600 ${user} users -"
    "d ${piMcpOAuthDir} 0700 ${user} users -"
    "d ${piSessionDir} 0700 ${user} users -"
    "d ${piStateDir} 0700 ${user} users -"
    "L+ ${piAgentDir}/sessions - - - - ${piSessionDir}"
    "L+ ${piAgentDir}/AGENTS.md - - - - ${../../../pi/AGENTS.md}"
    "L+ ${piAgentDir}/settings.json - - - - ${piSettingsFile}"
    "L+ ${piAgentDir}/auth.json - - - - ${piAuthFile}"
    "L+ ${piSkillsDir}/todoist-cli - - - - ${todoistCliPiSkill}/skills/todoist-cli"
    "L+ ${piPackagesDir}/pi-web-minimal - - - - ${piWebMinimal}"
    "L+ ${piPackagesDir}/pi-mcp-adapter - - - - ${piMcpAdapter}"
  ];

  home-manager.users.${user} = {
    home.packages = [
      piPackage
      piMcpAdapterCli
    ];
    home.sessionVariables = piEnvironment;
  };
}

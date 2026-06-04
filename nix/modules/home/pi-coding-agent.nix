{
  agenixHome,
  piWebMinimalPackage,
  piMcpAdapterPackage,
  piAgentBrowserNativePackage,
  piSubagentsPackage,
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
  secretsDirectory = ../../../secrets;

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
  piAgentBrowserConfigDir = "${localDirectory}/config/pi/agent-browser-native";
  piAgentBrowserConfigFile = "${piAgentBrowserConfigDir}/config.json";
  piPackagesDir = "${piAgentDir}/packages";
  piSkillsDir = "${piAgentDir}/skills";
  piExtensionsDir = "${piAgentDir}/extensions";
  piSubagentsConfigDir = "${piExtensionsDir}/subagent";
  piSubagentsStateDir = "${localDirectory}/state/pi/subagents";
  piSubagentsAgentsDir = "${localDirectory}/hacks/pi/subagents/agents";
  piSubagentsChainsDir = "${localDirectory}/hacks/pi/subagents/chains";
  piSubagentsRunHistoryFile = "${piSubagentsStateDir}/run-history.jsonl";
  piWebMinimalExaApiKeyFile = "${localDirectory}/config/pi/web-minimal/exa-api-key";
  piWebMinimalContext7ApiKeyFile = "${localDirectory}/config/pi/web-minimal/context7-api-key";

  agentToolPath = lib.makeBinPath [ pkgs.python3 ];

  piWebMinimal = piWebMinimalPackage pkgs;
  piMcpAdapter = piMcpAdapterPackage pkgs;
  piAgentBrowserNative = piAgentBrowserNativePackage pkgs;
  piSubagents = piSubagentsPackage pkgs;
  todoistCliPiSkill = pkgs.todoist-cli-pi-skill;
  piMcpCacheFile = "${piStateDir}/mcp-cache.json";
  piMcpOnboardingFile = "${piStateDir}/mcp-onboarding.json";
  piRequiredPackages = [
    "packages/pi-web-minimal"
    "packages/pi-subagents"
  ];
  piSubagentsConfig = pkgs.writeText "pi-subagents-config.json" (
    builtins.toJSON {
      defaultSessionDir = "${piSessionDir}/subagent";
    }
  );

  piEnvironment = {
    PI_CODING_AGENT_DIR = piAgentDir;
    PI_MCP_CONFIG = piMcpConfigFile;
    PI_MCP_CACHE = piMcpCacheFile;
    PI_MCP_ONBOARDING_STATE = piMcpOnboardingFile;
    MCP_OAUTH_DIR = piMcpOAuthDir;
    PI_AGENT_BROWSER_CONFIG = piAgentBrowserConfigFile;
  };

  seededSettings = pkgs.writeText "pi-settings.json" (
    builtins.toJSON {
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.5";
      defaultThinkingLevel = "high";
      enableInstallTelemetry = false;
      packages = piRequiredPackages;
    }
  );

  piPackage = pkgs.writeShellScriptBin "pi" ''
    set -euo pipefail

    export PI_CODING_AGENT_DIR=${lib.escapeShellArg piAgentDir}
    export PI_MCP_CONFIG=${lib.escapeShellArg piMcpConfigFile}
    export PI_MCP_CACHE=${lib.escapeShellArg piMcpCacheFile}
    export PI_MCP_ONBOARDING_STATE=${lib.escapeShellArg piMcpOnboardingFile}
    export MCP_OAUTH_DIR=${lib.escapeShellArg piMcpOAuthDir}
    export PI_AGENT_BROWSER_CONFIG=${lib.escapeShellArg piAgentBrowserConfigFile}
    export PATH=${lib.escapeShellArg agentToolPath}:''${PATH:-}

    if [ -r ${lib.escapeShellArg piWebMinimalExaApiKeyFile} ]; then
      export EXA_API_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg piWebMinimalExaApiKeyFile})"
    fi

    if [ -r ${lib.escapeShellArg piWebMinimalContext7ApiKeyFile} ]; then
      export CONTEXT7_API_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg piWebMinimalContext7ApiKeyFile})"
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
  # keybindings.json, SYSTEM.md/APPEND_SYSTEM.md, other extensions/,
  # other skills/, prompts/, themes/, git/, npm/, bin/fd, bin/rg,
  # pi-debug.log, project-local .pi/, and arbitrary third-party extension
  # state.
  system.activationScripts.migratePiCodingAgent = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piShareDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piAgentDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piPackagesDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piSkillsDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piExtensionsDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piSubagentsConfigDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSettingsDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piMcpConfigDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piAuthDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piMcpOAuthDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piAgentBrowserConfigDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSessionDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSessionDir}/subagent
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piStateDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSubagentsStateDir}
      install -d -m 0700 -o ${user} -g users ${
        lib.escapeShellArg (localDirectory + "/hacks/pi/subagents")
      }
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSubagentsAgentsDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piSubagentsChainsDir}
      touch ${lib.escapeShellArg piSubagentsRunHistoryFile}
      chown ${user}:users ${lib.escapeShellArg piSubagentsRunHistoryFile}
      chmod 0600 ${lib.escapeShellArg piSubagentsRunHistoryFile}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${piShareDir} 0755 ${user} users -"
    "d ${piAgentDir} 0700 ${user} users -"
    "d ${piPackagesDir} 0755 ${user} users -"
    "d ${piSkillsDir} 0755 ${user} users -"
    "d ${piExtensionsDir} 0755 ${user} users -"
    "d ${piSubagentsConfigDir} 0755 ${user} users -"
    "d ${piSettingsDir} 0700 ${user} users -"
    "r ${piSettingsFile}"
    "C ${piSettingsFile} 0600 ${user} users - ${seededSettings}"
    "d ${piMcpConfigDir} 0700 ${user} users -"
    "d ${piAuthDir} 0700 ${user} users -"
    "f ${piAuthFile} 0600 ${user} users -"
    "d ${piMcpOAuthDir} 0700 ${user} users -"
    "d ${piAgentBrowserConfigDir} 0700 ${user} users -"
    "d ${piSessionDir} 0700 ${user} users -"
    "d ${piSessionDir}/subagent 0700 ${user} users -"
    "d ${piStateDir} 0700 ${user} users -"
    "d ${piSubagentsStateDir} 0700 ${user} users -"
    "d ${localDirectory}/hacks/pi/subagents 0700 ${user} users -"
    "d ${piSubagentsAgentsDir} 0700 ${user} users -"
    "d ${piSubagentsChainsDir} 0700 ${user} users -"
    "f ${piSubagentsRunHistoryFile} 0600 ${user} users -"
    "L+ ${piAgentDir}/sessions - - - - ${piSessionDir}"
    "L+ ${piAgentDir}/AGENTS.md - - - - ${../../../pi/AGENTS.md}"
    "L+ ${piExtensionsDir}/tame-shell.ts - - - - ${../../../pi/extensions/tame-shell.ts}"
    "L+ ${piAgentDir}/settings.json - - - - ${piSettingsFile}"
    "L+ ${piAgentDir}/auth.json - - - - ${piAuthFile}"
    "L+ ${piAgentDir}/agents - - - - ${piSubagentsAgentsDir}"
    "L+ ${piAgentDir}/chains - - - - ${piSubagentsChainsDir}"
    "L+ ${piAgentDir}/run-history.jsonl - - - - ${piSubagentsRunHistoryFile}"
    "L+ ${piSubagentsConfigDir}/config.json - - - - ${piSubagentsConfig}"
    "L+ ${piSkillsDir}/todoist-cli - - - - ${todoistCliPiSkill}/skills/todoist-cli"
    "L+ ${piPackagesDir}/pi-web-minimal - - - - ${piWebMinimal}"
    "L+ ${piPackagesDir}/pi-mcp-adapter - - - - ${piMcpAdapter}"
    "L+ ${piPackagesDir}/pi-agent-browser-native - - - - ${piAgentBrowserNative}"
    "L+ ${piPackagesDir}/pi-subagents - - - - ${piSubagents}"
  ];

  home-manager.users.${user} = {
    imports = [ agenixHome ];

    age = {
      identityPaths = [ "${localDirectory}/secrets/ssh/id_ed25519" ];

      secrets = {
        exaApiKey = {
          file = secretsDirectory + "/exa-api-key.age";
          path = piWebMinimalExaApiKeyFile;
        };

        context7ApiKey = {
          file = secretsDirectory + "/context7-api-key.age";
          path = piWebMinimalContext7ApiKeyFile;
        };
      };
    };

    home.packages = [
      piPackage
      piMcpAdapterCli
    ];

    home.sessionVariables = piEnvironment;
  };
}

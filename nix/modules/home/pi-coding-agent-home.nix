{
  agenixHome,
  piWebMinimalPackage,
  piMcpAdapterPackage,
  piSubagentsPackage,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.jackson.piCodingAgent;
  secretsDirectory = ../../../secrets;

  piPackagesDir = "${cfg.agentDir}/packages";
  piSkillsDir = "${cfg.agentDir}/skills";
  piExtensionsDir = "${cfg.agentDir}/extensions";
  piSubagentsConfigDir = "${piExtensionsDir}/subagent";

  piSettingsFile = "${cfg.settingsDir}/settings.json";
  piMcpConfigFile = "${cfg.mcpConfigDir}/mcp.json";
  piAuthFile = "${cfg.authDir}/auth.json";
  piMcpCacheFile = "${cfg.mcpStateDir}/mcp-cache.json";
  piMcpOnboardingFile = "${cfg.mcpStateDir}/mcp-onboarding.json";
  piSubagentsRunHistoryFile = "${cfg.subagentsStateDir}/run-history.jsonl";

  piWebMinimal = piWebMinimalPackage pkgs;
  piMcpAdapter = piMcpAdapterPackage pkgs;
  piSubagents = piSubagentsPackage pkgs;
  todoistCliPiSkill = pkgs.todoist-cli-pi-skill;

  piEnvironment = {
    PI_CODING_AGENT_DIR = cfg.agentDir;
    PI_MCP_CONFIG = piMcpConfigFile;
    PI_MCP_CACHE = piMcpCacheFile;
    PI_MCP_ONBOARDING_STATE = piMcpOnboardingFile;
    MCP_OAUTH_DIR = cfg.mcpOAuthDir;
  };

  seededSettings = pkgs.writeText "pi-settings.json" (
    builtins.toJSON {
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.5";
      defaultThinkingLevel = "high";
      enableInstallTelemetry = false;
      packages = cfg.requiredPackages;
    }
  );

  piSubagentsConfig = pkgs.writeText "pi-subagents-config.json" (
    builtins.toJSON {
      defaultSessionDir = "${cfg.sessionDir}/subagent";
    }
  );

  sourceWebMinimalEnv = lib.optionalString (cfg.webMinimalEnvFile != null) ''
    if [ -r ${lib.escapeShellArg cfg.webMinimalEnvFile} ]; then
      . ${lib.escapeShellArg cfg.webMinimalEnvFile}
    fi
  '';

  sourceWebMinimalSecretFiles = ''
    if [ -r ${lib.escapeShellArg cfg.webMinimalExaApiKeyFile} ]; then
      export EXA_API_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.webMinimalExaApiKeyFile})"
    fi

    if [ -r ${lib.escapeShellArg cfg.webMinimalContext7ApiKeyFile} ]; then
      export CONTEXT7_API_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.webMinimalContext7ApiKeyFile})"
    fi
  '';

  piPackage = pkgs.writeShellScriptBin "pi" ''
    set -euo pipefail

    export PI_CODING_AGENT_DIR=${lib.escapeShellArg cfg.agentDir}
    export PI_MCP_CONFIG=${lib.escapeShellArg piMcpConfigFile}
    export PI_MCP_CACHE=${lib.escapeShellArg piMcpCacheFile}
    export PI_MCP_ONBOARDING_STATE=${lib.escapeShellArg piMcpOnboardingFile}
    export MCP_OAUTH_DIR=${lib.escapeShellArg cfg.mcpOAuthDir}

    ${sourceWebMinimalEnv}
    ${sourceWebMinimalSecretFiles}

    exec ${pkgs.llm-agents.pi}/bin/pi "$@"
  '';

  piMcpAdapterCli = pkgs.writeShellScriptBin "pi-mcp-adapter" ''
    set -euo pipefail

    export PI_CODING_AGENT_DIR=${lib.escapeShellArg cfg.agentDir}
    export PI_MCP_CONFIG=${lib.escapeShellArg piMcpConfigFile}
    export PI_MCP_CACHE=${lib.escapeShellArg piMcpCacheFile}
    export PI_MCP_ONBOARDING_STATE=${lib.escapeShellArg piMcpOnboardingFile}
    export MCP_OAUTH_DIR=${lib.escapeShellArg cfg.mcpOAuthDir}

    exec ${pkgs.nodejs}/bin/node ${piMcpAdapter}/cli.js "$@"
  '';

  directorySpecs = [
    {
      path = cfg.agentDir;
      mode = "0700";
    }
    {
      path = piPackagesDir;
      mode = "0755";
    }
    {
      path = piSkillsDir;
      mode = "0755";
    }
    {
      path = piExtensionsDir;
      mode = "0755";
    }
    {
      path = piSubagentsConfigDir;
      mode = "0755";
    }
    {
      path = cfg.settingsDir;
      mode = "0700";
    }
    {
      path = cfg.mcpConfigDir;
      mode = "0700";
    }
    {
      path = cfg.authDir;
      mode = "0700";
    }
    {
      path = cfg.mcpOAuthDir;
      mode = "0700";
    }
    {
      path = cfg.sessionDir;
      mode = "0700";
    }
    {
      path = "${cfg.sessionDir}/subagent";
      mode = "0700";
    }
    {
      path = cfg.mcpStateDir;
      mode = "0700";
    }
    {
      path = cfg.subagentsStateDir;
      mode = "0700";
    }
    {
      path = builtins.dirOf cfg.subagentsAgentsDir;
      mode = "0700";
    }
    {
      path = cfg.subagentsAgentsDir;
      mode = "0700";
    }
    {
      path = cfg.subagentsChainsDir;
      mode = "0700";
    }
  ];

  linkSpecs = [
    {
      link = "${cfg.agentDir}/sessions";
      target = cfg.sessionDir;
    }
    {
      link = "${cfg.agentDir}/AGENTS.md";
      target = ../../../pi/AGENTS.md;
    }
    {
      link = "${cfg.agentDir}/settings.json";
      target = piSettingsFile;
    }
    {
      link = "${cfg.agentDir}/auth.json";
      target = piAuthFile;
    }
    {
      link = "${cfg.agentDir}/agents";
      target = cfg.subagentsAgentsDir;
    }
    {
      link = "${cfg.agentDir}/chains";
      target = cfg.subagentsChainsDir;
    }
    {
      link = "${cfg.agentDir}/run-history.jsonl";
      target = piSubagentsRunHistoryFile;
    }
    {
      link = "${piSubagentsConfigDir}/config.json";
      target = piSubagentsConfig;
    }
    {
      link = "${piSkillsDir}/todoist-cli";
      target = "${todoistCliPiSkill}/skills/todoist-cli";
    }
    {
      link = "${piPackagesDir}/pi-web-minimal";
      target = piWebMinimal;
    }
    {
      link = "${piPackagesDir}/pi-mcp-adapter";
      target = piMcpAdapter;
    }
    {
      link = "${piPackagesDir}/pi-subagents";
      target = piSubagents;
    }
  ];

  createDirectories = lib.concatMapStringsSep "\n" (directory: ''
    $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg directory.path}
    $DRY_RUN_CMD chmod ${directory.mode} ${lib.escapeShellArg directory.path}
  '') directorySpecs;

  createLinks = lib.concatMapStringsSep "\n" (link: ''
    if [ -e ${lib.escapeShellArg link.link} ] && [ ! -L ${lib.escapeShellArg link.link} ]; then
      echo "warning: refusing to replace non-symlink ${link.link}" >&2
    else
      $DRY_RUN_CMD ln -sfn ${lib.escapeShellArg link.target} ${lib.escapeShellArg link.link}
    fi
  '') linkSpecs;
in
{
  imports = [ agenixHome ];

  options.jackson.piCodingAgent = {
    agentDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/pi/agent";
      description = "Pi coding agent runtime directory.";
    };

    sessionDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/pi/sessions";
      description = "Pi session directory.";
    };

    mcpStateDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/pi/mcp";
      description = "Pi MCP cache and onboarding state directory.";
    };

    settingsDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/pi/settings";
      description = "Pi settings directory.";
    };

    mcpConfigDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/pi/mcp";
      description = "Pi MCP configuration directory.";
    };

    authDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/pi/auth";
      description = "Pi auth directory.";
    };

    mcpOAuthDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/pi/mcp-oauth";
      description = "Pi MCP OAuth credential directory.";
    };

    subagentsStateDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/pi/subagents";
      description = "Pi subagents runtime state directory.";
    };

    subagentsAgentsDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/pi/subagents/agents";
      description = "Pi subagents user agents directory.";
    };

    subagentsChainsDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/pi/subagents/chains";
      description = "Pi subagents user chains directory.";
    };

    requiredPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "packages/pi-web-minimal"
        "packages/pi-subagents"
      ];
      description = "Package paths to seed into Pi settings.json.";
    };

    webMinimalEnvFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional shell environment file sourced by the pi wrapper.";
    };

    webMinimalExaApiKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/pi/web-minimal/exa-api-key";
      description = "File containing the Exa API key for pi-web-minimal.";
    };

    webMinimalContext7ApiKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/pi/web-minimal/context7-api-key";
      description = "File containing the Context7 API key for pi-web-minimal.";
    };
  };

  config = {
    age = {
      identityPaths = lib.mkDefault [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];

      secrets = {
        exaApiKey = {
          file = secretsDirectory + "/exa-api-key.age";
          path = cfg.webMinimalExaApiKeyFile;
        };

        context7ApiKey = {
          file = secretsDirectory + "/context7-api-key.age";
          path = cfg.webMinimalContext7ApiKeyFile;
        };
      };
    };

    home.packages = [
      piPackage
      piMcpAdapterCli
    ];

    home.sessionVariables = piEnvironment;

    home.activation.preparePiCodingAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${createDirectories}

      if [ ! -e ${lib.escapeShellArg piSettingsFile} ]; then
        $DRY_RUN_CMD cp ${lib.escapeShellArg seededSettings} ${lib.escapeShellArg piSettingsFile}
        $DRY_RUN_CMD chmod 0600 ${lib.escapeShellArg piSettingsFile}
      fi

      if [ ! -e ${lib.escapeShellArg piAuthFile} ]; then
        $DRY_RUN_CMD touch ${lib.escapeShellArg piAuthFile}
      fi
      $DRY_RUN_CMD chmod 0600 ${lib.escapeShellArg piAuthFile}

      if [ ! -e ${lib.escapeShellArg piSubagentsRunHistoryFile} ]; then
        $DRY_RUN_CMD touch ${lib.escapeShellArg piSubagentsRunHistoryFile}
      fi
      $DRY_RUN_CMD chmod 0600 ${lib.escapeShellArg piSubagentsRunHistoryFile}

      ${createLinks}
    '';
  };
}

{
  piCodingAgentHome,
  piWebMinimalPackage,
  piMcpAdapterPackage,
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
  piConfigHome = config.home-manager.users.${user}.jackson.piCodingAgent;

  piShareDir = builtins.dirOf piConfigHome.agentDir;
  piPackagesDir = "${piConfigHome.agentDir}/packages";
  piSkillsDir = "${piConfigHome.agentDir}/skills";
  piExtensionsDir = "${piConfigHome.agentDir}/extensions";
  piSubagentsConfigDir = "${piExtensionsDir}/subagent";

  piSettingsFile = "${piConfigHome.settingsDir}/settings.json";
  piMcpConfigFile = "${piConfigHome.mcpConfigDir}/mcp.json";
  piAuthFile = "${piConfigHome.authDir}/auth.json";
  piMcpCacheFile = "${piConfigHome.mcpStateDir}/mcp-cache.json";
  piMcpOnboardingFile = "${piConfigHome.mcpStateDir}/mcp-onboarding.json";
  piSubagentsRunHistoryFile = "${piConfigHome.subagentsStateDir}/run-history.jsonl";

  piWebMinimal = piWebMinimalPackage pkgs;
  piMcpAdapter = piMcpAdapterPackage pkgs;
  piSubagents = piSubagentsPackage pkgs;
  todoistCliPiSkill = pkgs.todoist-cli-pi-skill;
  piSubagentsConfig = pkgs.writeText "pi-subagents-config.json" (
    builtins.toJSON {
      defaultSessionDir = "${piConfigHome.sessionDir}/subagent";
    }
  );

  seededSettings = pkgs.writeText "pi-settings.json" (
    builtins.toJSON {
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.5";
      defaultThinkingLevel = "high";
      enableInstallTelemetry = false;
      packages = piConfigHome.requiredPackages;
    }
  );

  piEnvironment = {
    PI_CODING_AGENT_DIR = piConfigHome.agentDir;
    PI_MCP_CONFIG = piMcpConfigFile;
    PI_MCP_CACHE = piMcpCacheFile;
    PI_MCP_ONBOARDING_STATE = piMcpOnboardingFile;
    MCP_OAUTH_DIR = piConfigHome.mcpOAuthDir;
  };
in
{
  nixpkgs.overlays = [ todoistCliOverlay ];

  systemd.services."user@${uid}" = {
    overrideStrategy = "asDropin";
    environment = piEnvironment;
  };

  systemd.services."home-manager-${user}".environment = piEnvironment;

  # Pi's core state is not XDG-native, so keep the runtime agent directory
  # ephemeral and link only the chosen durable pieces into it. This NixOS layer
  # contains murph's boot/impermanence repair policy; the shared Home Manager
  # module contains the package wrappers and cross-platform agent layout.
  # Known possible future state to classify if it appears: models.json,
  # keybindings.json, SYSTEM.md/APPEND_SYSTEM.md, other extensions/,
  # other skills/, prompts/, themes/, git/, npm/, bin/fd, bin/rg,
  # pi-debug.log, project-local .pi/, and arbitrary third-party extension
  # state.
  system.activationScripts.migratePiCodingAgent = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piShareDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.agentDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piPackagesDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piSkillsDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piExtensionsDir}
      install -d -m 0755 -o ${user} -g users ${lib.escapeShellArg piSubagentsConfigDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.settingsDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.mcpConfigDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.authDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.mcpOAuthDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.sessionDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.sessionDir}/subagent
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.mcpStateDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.subagentsStateDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg (builtins.dirOf piConfigHome.subagentsAgentsDir)}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.subagentsAgentsDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg piConfigHome.subagentsChainsDir}
      touch ${lib.escapeShellArg piSubagentsRunHistoryFile}
      chown ${user}:users ${lib.escapeShellArg piSubagentsRunHistoryFile}
      chmod 0600 ${lib.escapeShellArg piSubagentsRunHistoryFile}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${piShareDir} 0755 ${user} users -"
    "d ${piConfigHome.agentDir} 0700 ${user} users -"
    "d ${piPackagesDir} 0755 ${user} users -"
    "d ${piSkillsDir} 0755 ${user} users -"
    "d ${piExtensionsDir} 0755 ${user} users -"
    "d ${piSubagentsConfigDir} 0755 ${user} users -"
    "d ${piConfigHome.settingsDir} 0700 ${user} users -"
    "r ${piSettingsFile}"
    "C ${piSettingsFile} 0600 ${user} users - ${seededSettings}"
    "d ${piConfigHome.mcpConfigDir} 0700 ${user} users -"
    "d ${piConfigHome.authDir} 0700 ${user} users -"
    "f ${piAuthFile} 0600 ${user} users -"
    "d ${piConfigHome.mcpOAuthDir} 0700 ${user} users -"
    "d ${piConfigHome.sessionDir} 0700 ${user} users -"
    "d ${piConfigHome.sessionDir}/subagent 0700 ${user} users -"
    "d ${piConfigHome.mcpStateDir} 0700 ${user} users -"
    "d ${piConfigHome.subagentsStateDir} 0700 ${user} users -"
    "d ${builtins.dirOf piConfigHome.subagentsAgentsDir} 0700 ${user} users -"
    "d ${piConfigHome.subagentsAgentsDir} 0700 ${user} users -"
    "d ${piConfigHome.subagentsChainsDir} 0700 ${user} users -"
    "f ${piSubagentsRunHistoryFile} 0600 ${user} users -"
    "L+ ${piConfigHome.agentDir}/sessions - - - - ${piConfigHome.sessionDir}"
    "L+ ${piConfigHome.agentDir}/AGENTS.md - - - - ${../../../pi/AGENTS.md}"
    "L+ ${piConfigHome.agentDir}/settings.json - - - - ${piSettingsFile}"
    "L+ ${piConfigHome.agentDir}/auth.json - - - - ${piAuthFile}"
    "L+ ${piConfigHome.agentDir}/agents - - - - ${piConfigHome.subagentsAgentsDir}"
    "L+ ${piConfigHome.agentDir}/chains - - - - ${piConfigHome.subagentsChainsDir}"
    "L+ ${piConfigHome.agentDir}/run-history.jsonl - - - - ${piSubagentsRunHistoryFile}"
    "L+ ${piSubagentsConfigDir}/config.json - - - - ${piSubagentsConfig}"
    "L+ ${piSkillsDir}/todoist-cli - - - - ${todoistCliPiSkill}/skills/todoist-cli"
    "L+ ${piPackagesDir}/pi-web-minimal - - - - ${piWebMinimal}"
    "L+ ${piPackagesDir}/pi-mcp-adapter - - - - ${piMcpAdapter}"
    "L+ ${piPackagesDir}/pi-subagents - - - - ${piSubagents}"
  ];

  home-manager.users.${user} = {
    imports = [ piCodingAgentHome ];

    age.identityPaths = [ "${localDirectory}/secrets/ssh/id_ed25519" ];

    jackson.piCodingAgent = {
      agentDir = "${localDirectory}/share/pi/agent";
      sessionDir = "${localDirectory}/state/pi/sessions";
      mcpStateDir = "${localDirectory}/state/pi/mcp";
      settingsDir = "${localDirectory}/hacks/pi/settings";
      mcpConfigDir = "${localDirectory}/secrets/pi/mcp";
      authDir = "${localDirectory}/secrets/pi/auth";
      mcpOAuthDir = "${localDirectory}/secrets/pi/mcp-oauth";
      subagentsStateDir = "${localDirectory}/state/pi/subagents";
      subagentsAgentsDir = "${localDirectory}/hacks/pi/subagents/agents";
      subagentsChainsDir = "${localDirectory}/hacks/pi/subagents/chains";
    };
  };
}

{ llmAgentsOverlay }:

{
  config,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;

  # Claude Code's native CLAUDE_CONFIG_DIR relocates the normal ~/.claude
  # tree. Persist that whole tree.
  claudeStateDir = "${localDirectory}/state/claude-code";
in
{
  nixpkgs.overlays = [ llmAgentsOverlay ];

  systemd.tmpfiles.rules = [
    "d ${claudeStateDir} 0700 ${user} users -"
  ];

  home-manager.users.${user} = {
    home.packages = [ pkgs.llm-agents.claude-code ];
    home.sessionVariables.CLAUDE_CONFIG_DIR = claudeStateDir;
  };
}

{ llmAgentsOverlay }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;

  # Claude Code's native CLAUDE_CONFIG_DIR relocates the normal ~/.claude
  # tree. Persist that whole tree.
  claudeStateDir = "${localDirectory}/state/claude-code";

  agentToolPath = lib.makeBinPath [ pkgs.python3 ];
  claudeCodePackage = pkgs.symlinkJoin {
    name = "claude-code-agent-tools";
    paths = [ pkgs.llm-agents.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f "$out/bin/claude"
      makeWrapper ${pkgs.llm-agents.claude-code}/bin/claude "$out/bin/claude" \
        --prefix PATH : ${lib.escapeShellArg agentToolPath}
    '';
  };
in
{
  nixpkgs.overlays = [ llmAgentsOverlay ];

  systemd.tmpfiles.rules = [
    "d ${claudeStateDir} 0700 ${user} users -"
  ];

  home-manager.users.${user} = {
    home.packages = [ claudeCodePackage ];
    home.sessionVariables.CLAUDE_CONFIG_DIR = claudeStateDir;
  };
}

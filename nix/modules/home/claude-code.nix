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
  agentInstructions = import ../../packages/agent-instructions.nix;

  # Claude Code's native CLAUDE_CONFIG_DIR relocates the normal ~/.claude
  # tree. Persist that whole tree.
  claudeStateDir = "${localDirectory}/state/claude-code";

  # Shared user-global skills are immutable and entirely Nix-managed. Claude
  # Code follows this directory symlink into the store.
  skillsSource = builtins.path {
    name = "skills";
    path = ../../../agents/skills;
  };
  claudeSkillsDir = "${claudeStateDir}/skills";

  # Shared user-global agent instructions, also consumed by Codex. Claude Code
  # reads CLAUDE.md rather than AGENTS.md, so it reaches the same store file
  # under that name.
  instructionsSource = agentInstructions.assembleAgentInstructions {
    inherit pkgs;
    machine = ../../../agents/machines/murph.md;
  };
  claudeInstructionsFile = "${claudeStateDir}/CLAUDE.md";

  agentToolPath = lib.makeBinPath [
    pkgs.python3
    pkgs.sox
  ];
  claudeCodePackage = pkgs.symlinkJoin {
    name = "claude-code-agent-tools";
    paths = [ pkgs.llm-agents.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f "$out/bin/claude"
      makeWrapper ${pkgs.llm-agents.claude-code}/bin/claude "$out/bin/claude" \
        --prefix PATH : ${lib.escapeShellArg agentToolPath} \
        --add-flags --dangerously-skip-permissions
    '';
  };
in
{
  nixpkgs.overlays = [ llmAgentsOverlay ];

  system.activationScripts.prepareClaudeCodeState = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg claudeStateDir}
      rm -rf ${lib.escapeShellArg claudeSkillsDir}
      ln -sfnT ${lib.escapeShellArg skillsSource} ${lib.escapeShellArg claudeSkillsDir}
      rm -f ${lib.escapeShellArg claudeInstructionsFile}
      ln -sfnT ${lib.escapeShellArg instructionsSource} ${lib.escapeShellArg claudeInstructionsFile}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${claudeStateDir} 0700 ${user} users -"
    "L+ ${claudeSkillsDir} - - - - ${skillsSource}"
    "L+ ${claudeInstructionsFile} - - - - ${instructionsSource}"
  ];

  home-manager.users.${user} = {
    home.packages = [ claudeCodePackage ];
    home.sessionVariables.CLAUDE_CONFIG_DIR = claudeStateDir;
  };
}

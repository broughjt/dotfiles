{
  config,
  lib,
  pkgs,
  ...
}:

let
  homeDirectory = config.defaultDirectories.homeDirectory;
  localDirectory = config.defaultDirectories.localDirectory;

  # Claude Code's native CLAUDE_CONFIG_DIR relocates the normal ~/.claude tree.
  # Everything under it is either a store symlink managed here or mutable state
  # the host persists on its own terms.
  claudeStateDirectory = "${localDirectory}/state/claude-code";

  # home.file keys are paths relative to the home directory.
  relativeToHome = path: lib.removePrefix "${homeDirectory}/" path;

  # Shared user-global skills are immutable and entirely Nix-managed. Claude
  # Code follows this directory symlink into the store.
  skillsSource = builtins.path {
    name = "skills";
    path = ../../../agents/skills;
  };

  claudeCodePackage = pkgs.callPackage ../../packages/claude-code.nix { };
in
{
  imports = [ ./agent-instructions.nix ];

  home.packages = [ claudeCodePackage ];
  home.sessionVariables.CLAUDE_CONFIG_DIR = claudeStateDirectory;

  # Credentials and project transcripts live here, so the directory has to be
  # private before anything is linked into it. A host with impermanence has
  # already created it by this point; this keeps the mode right on hosts that
  # create it here for the first time.
  home.activation.claudeCodeStateDirectory = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    run install -d -m 0700 ${lib.escapeShellArg claudeStateDirectory}
  '';

  # Both targets are store paths by definition, so anything found sitting at
  # one is a stale link from an older generation rather than state worth
  # keeping. Claude Code reads CLAUDE.md rather than AGENTS.md, so the shared
  # agent instructions reach it under that name.
  home.file.${relativeToHome "${claudeStateDirectory}/skills"} = {
    source = skillsSource;
    force = true;
  };

  home.file.${relativeToHome "${claudeStateDirectory}/CLAUDE.md"} = {
    source = config.agentInstructions.file;
    force = true;
  };
}

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

  # User-global skills, available to Claude Code in every project. Each
  # directory under claude/skills is store-backed and symlinked into
  # CLAUDE_CONFIG_DIR/skills; the persisted state tree never owns the content,
  # so editing a skill means editing the repository and rebuilding.
  claudeSkillsSource = ../../../claude/skills;
  claudeSkillsDir = "${claudeStateDir}/skills";
  claudeSkillNames = builtins.attrNames (
    lib.filterAttrs (_: entryType: entryType == "directory") (builtins.readDir claudeSkillsSource)
  );

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

  # The skills directory sits inside persisted state, so a skill that is
  # renamed or removed from the repository would otherwise keep its dangling
  # link forever. Re-link the declared set on every switch and drop
  # store-backed links that are no longer declared. Hand-written skills, which
  # are not symlinks into the store, are left alone.
  system.activationScripts.prepareClaudeCodeSkills = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg claudeStateDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg claudeSkillsDir}

      declared=${lib.escapeShellArg (lib.concatStringsSep "\n" claudeSkillNames)}
      for link in ${lib.escapeShellArg claudeSkillsDir}/*; do
        [ -L "$link" ] || continue
        case "$(readlink "$link")" in
          /nix/store/*) ;;
          *) continue ;;
        esac
        printf '%s\n' "$declared" | grep -qxF "$(basename "$link")" || rm -f "$link"
      done
    ''
    # A declared skill name is owned by this module: whatever sits at that path
    # is replaced by the store-backed link.
    + lib.concatMapStringsSep "\n" (name: ''
      rm -rf ${lib.escapeShellArg "${claudeSkillsDir}/${name}"}
      ln -sfnT ${lib.escapeShellArg "${claudeSkillsSource}/${name}"} ${lib.escapeShellArg "${claudeSkillsDir}/${name}"}
    '') claudeSkillNames;
  };

  systemd.tmpfiles.rules = [
    "d ${claudeStateDir} 0700 ${user} users -"
    "d ${claudeSkillsDir} 0700 ${user} users -"
  ]
  ++ map (
    name: "L+ ${claudeSkillsDir}/${name} - - - - ${claudeSkillsSource}/${name}"
  ) claudeSkillNames;

  home-manager.users.${user} = {
    home.packages = [ claudeCodePackage ];
    home.sessionVariables.CLAUDE_CONFIG_DIR = claudeStateDir;
  };
}

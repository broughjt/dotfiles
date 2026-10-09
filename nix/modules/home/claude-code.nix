{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude-code;

  defaultConfigFile =
    if cfg.configDir == "${config.home.homeDirectory}/.claude" then
      "${config.home.homeDirectory}/.claude.json"
    else
      "${cfg.configDir}/.claude.json";

  claudeRemote = pkgs.writeShellApplication {
    name = "claude-remote";
    runtimeInputs = [
      cfg.finalPackage
      config.programs.tmux.package
      pkgs.jq
    ];
    text = ''
      directory=$PWD
      configFile=${lib.escapeShellArg config.claudeCode.configFile}

      # Claude asks once per directory whether to trust it and has no flag or
      # setting to answer in advance, so a detached session would sit on that
      # prompt. Record the answer the way claude does. A running session may
      # overwrite the file when it exits; the cost of that is one prompt.
      [ -e "$configFile" ] || printf '{}\n' >"$configFile"
      temporary=$(mktemp "$configFile.XXXXXX")
      jq --arg directory "$directory" \
        '.projects[$directory].hasTrustDialogAccepted = true' \
        "$configFile" >"$temporary"
      mv "$temporary" "$configFile"

      index=1
      while tmux has-session -t "=claude-$index" 2>/dev/null; do
        index=$((index + 1))
      done
      name=claude-$index

      tmux new-session -d -s "$name" -c "$directory" -- claude "$@"
      echo "tmux attach -t $name"
    '';
  };
in
{
  imports = [
    ./agent-instructions.nix
    ./handoff.nix
  ];

  options.claudeCode.configFile = lib.mkOption {
    type = lib.types.str;
    default = defaultConfigFile;
    defaultText = lib.literalMD "`.claude.json` beside or inside `configDir`";
    description = ''
      Claude Code's global state file. Mutable application state rather than
      configuration, so nothing renders it; it is named here because other
      modules have to find it.
    '';
  };

  config = {
    home.packages = [ claudeRemote ];

    programs.claude-code = {
      enable = true;
      package = pkgs.callPackage ../../packages/claude-code.nix { };

      context = config.agentInstructions.text;

      skills = pkgs.handoff.skills;
    };
  };
}

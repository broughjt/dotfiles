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

  # Settings keys come and go between releases, and Claude Code ignores keys it
  # doesn't know, so a renamed setting would silently stop applying. Fail the
  # build instead: `claude doctor` reports values of the wrong type, and a key
  # the binary never mentions has almost certainly been removed.
  settingsCheck =
    pkgs.runCommand "claude-code-settings-check"
      {
        nativeBuildInputs = [ pkgs.jq ];
        settings = (pkgs.formats.json { }).generate "settings.json" cfg.settings;
        binary = "${cfg.finalPackage}/bin/.claude-wrapped";
      }
      ''
        mkdir -p "$TMPDIR/config"
        cp "$settings" "$TMPDIR/config/settings.json"

        report=$(cd "$TMPDIR" && HOME="$TMPDIR" CLAUDE_CONFIG_DIR="$TMPDIR/config" "$binary" doctor </dev/null 2>&1)
        if grep -q '^Invalid settings' <<<"$report"; then
          sed -n '/^Invalid settings/,/^$/p' <<<"$report" >&2
          exit 1
        fi

        unknown=()
        while read -r key; do
          grep -qaF "$key" "$binary" || unknown+=("$key")
        done < <(jq -r '[.. | objects | keys[]] | unique[]' "$settings")
        if [ ''${#unknown[@]} -gt 0 ]; then
          echo "settings keys not found in $binary: ''${unknown[*]}" >&2
          exit 1
        fi

        touch "$out"
      '';
in
{
  imports = [
    ./agent-instructions.nix
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
    home.extraDependencies = [ settingsCheck ];

    programs.claude-code = {
      enable = true;
      package = pkgs.callPackage ../../packages/claude-code.nix { };

      context = config.agentInstructions.text;

      mutableSettings = true;
      settings = {
        attribution = {
          commit = "";
          pr = "";
          sessionUrl = false;
        };
        promptSuggestionEnabled = false;
        theme = "auto";
        skipDangerousModePermissionPrompt = true;
        remoteControlAtStartup = true;
        agentPushNotifEnabled = true;
        cleanupPeriodDays = 3650;
      };
    };
  };
}

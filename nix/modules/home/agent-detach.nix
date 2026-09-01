{
  config,
  lib,
  pkgs,
  ...
}:

let
  agentDetach = pkgs.writeShellApplication {
    name = "agent-detach";
    runtimeInputs = [
      config.programs.tmux.package
      pkgs.jq
    ];
    text = ''
      claudeConfig=${lib.escapeShellArg config.claudeCode.configFile}
      codexConfig=${lib.escapeShellArg "${config.codex.configDirectory}/config.toml"}

      usage() {
        cat <<'EOF'
      agent-detach claude [prompt]   start a detached claude session here
      agent-detach codex [prompt]    start a detached codex session here

      Reattach with `tmux attach -t <name>`, and detach again with C-b d.
      EOF
      }

      # Both agents ask, once per directory, whether the directory is trusted,
      # and neither has a flag to answer in advance: claude documents the
      # dialog as skipped only in non-interactive mode, and codex reads its
      # trust map from config.toml before command-line overrides are merged. A
      # session started detached would sit on that prompt forever, so record
      # the answer the way the tools themselves record it before starting one.
      # Both files are mutable application state, so a session already running
      # may overwrite this when it exits; the cost of losing it is one prompt.
      trustClaude() {
        local directory=$1 temporary
        [ -e "$claudeConfig" ] || printf '{}\n' >"$claudeConfig"
        temporary=$(mktemp "$claudeConfig.XXXXXX")
        jq --arg directory "$directory" \
          '.projects[$directory].hasTrustDialogAccepted = true' \
          "$claudeConfig" >"$temporary"
        mv "$temporary" "$claudeConfig"
      }

      trustCodex() {
        local directory=$1
        if ! grep -qF "[projects.\"$directory\"]" "$codexConfig" 2>/dev/null; then
          printf '\n[projects."%s"]\ntrust_level = "trusted"\n' \
            "$directory" >>"$codexConfig"
        fi
      }

      start() {
        local tool=$1 directory index name
        shift
        directory=$PWD

        case "$tool" in
          claude) trustClaude "$directory" ;;
          codex) trustCodex "$directory" ;;
        esac

        index=1
        while tmux has-session -t "=$tool-$index" 2>/dev/null; do
          index=$((index + 1))
        done
        name=$tool-$index

        tmux new-session -d -s "$name" -c "$directory" -- "$tool" "$@"
        echo "$name: $tool in $directory"
        echo "tmux attach -t $name"
      }

      case "''${1-}" in
        claude | codex) start "$@" ;;
        "" | -h | --help | help)
          usage
          echo
          tmux list-sessions 2>/dev/null || echo "no sessions"
          ;;
        *)
          usage >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  # Reading claudeCode.configFile and codex.configDirectory makes this a hard
  # dependency on both leaves: an undeclared option is an evaluation error, so
  # a host importing this one has to import homeClaudeCode and homeCodex too.
  # Importing them here instead does not work. The registry holds each module
  # as `import ./home/<name>.nix`, an already-evaluated function, which the
  # module system cannot match against the same file imported as a path -- both
  # definitions are kept, and `programs.claude-code.package` is then defined
  # twice.
  home.packages = [ agentDetach ];
}

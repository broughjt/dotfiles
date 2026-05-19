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

  # Claude Code supports relocating its global ~/.claude directory with
  # CLAUDE_CONFIG_DIR. Keep that aggregate directory ephemeral and link/copy
  # only selected durable state into explicit persisted subdirectories.
  claudeShareDir = "${localDirectory}/share/claude-code";
  claudeConfigDir = "${claudeShareDir}/config";
  claudeRuntimeDir = "${claudeShareDir}/runtime";
  claudeStateDir = "${localDirectory}/state/claude-code";
  claudeHistoryDir = "${claudeStateDir}/history";
  claudeProjectsDir = "${claudeStateDir}/projects";
  claudeSessionsDir = "${claudeStateDir}/sessions";
  claudeSecretsDir = "${localDirectory}/secrets/claude-code";
  claudeAuthDir = "${claudeSecretsDir}/auth";
  claudeCredentialsDir = "${claudeSecretsDir}/credentials";

  claudeWrapper = pkgs.writeShellScript "claude-code-local-state-wrapper" ''
    set -euo pipefail

    export CLAUDE_CONFIG_DIR=${lib.escapeShellArg claudeConfigDir}

    config_dir=${lib.escapeShellArg claudeConfigDir}
    runtime_dir=${lib.escapeShellArg claudeRuntimeDir}
    history_dir=${lib.escapeShellArg claudeHistoryDir}
    projects_dir=${lib.escapeShellArg claudeProjectsDir}
    sessions_dir=${lib.escapeShellArg claudeSessionsDir}
    auth_dir=${lib.escapeShellArg claudeAuthDir}
    credentials_dir=${lib.escapeShellArg claudeCredentialsDir}
    lock_file="$runtime_dir/state-sync.lock"

    install -d -m 0700 \
      "$config_dir" \
      "$runtime_dir" \
      "$history_dir" \
      "$projects_dir" \
      "$sessions_dir" \
      "$auth_dir" \
      "$credentials_dir"

    link_persisted_dir() {
      name=$1
      target=$2
      source="$config_dir/$name"

      install -d -m 0700 "$target"

      if [ -L "$source" ]; then
        rm -f "$source"
      elif [ -d "$source" ]; then
        ${pkgs.coreutils}/bin/cp -a "$source/." "$target/" 2>/dev/null || true
        rm -rf "$source"
      elif [ -e "$source" ]; then
        echo "warning: $source exists and is not a directory; leaving it ephemeral and not replacing it" >&2
        return 0
      fi

      ln -sfn "$target" "$source"
    }

    sync_from_persistent() {
      (
        ${pkgs.util-linux}/bin/flock -x 9

        for file in .claude.json .credentials.json; do
          if [ -e "$auth_dir/$file" ]; then
            install -m 0600 "$auth_dir/$file" "$config_dir/$file"
          fi
        done

        if [ -e "$history_dir/history.jsonl" ]; then
          install -m 0600 "$history_dir/history.jsonl" "$config_dir/history.jsonl"
        fi

        # Persist auth/provider credential profiles, session metadata, and
        # conversation transcripts. Keep shell snapshots, file-history,
        # paste/image caches, debug logs, plans, backups, stats-cache, and
        # other Claude Code application data ephemeral in CLAUDE_CONFIG_DIR.
        link_persisted_dir credentials "$credentials_dir"
        link_persisted_dir projects "$projects_dir"
        link_persisted_dir sessions "$sessions_dir"
      ) 9>"$lock_file"
    }

    sync_to_persistent() {
      (
        ${pkgs.util-linux}/bin/flock -x 9

        for file in .claude.json .credentials.json; do
          if [ -e "$config_dir/$file" ]; then
            install -m 0600 "$config_dir/$file" "$auth_dir/$file"
          fi
        done

        if [ -e "$config_dir/history.jsonl" ]; then
          install -m 0600 "$config_dir/history.jsonl" "$history_dir/history.jsonl"
        fi
      ) 9>"$lock_file"
    }

    sync_on_exit() {
      status=$?
      sync_to_persistent || true
      exit "$status"
    }

    sync_from_persistent
    trap sync_on_exit EXIT

    ${pkgs.llm-agents.claude-code}/bin/claude "$@"
  '';

  claudePackage = pkgs.symlinkJoin {
    name = "claude-code-local-state";
    paths = [ pkgs.llm-agents.claude-code ];
    postBuild = ''
      rm -f "$out/bin/claude"
      install -D -m 0755 ${claudeWrapper} "$out/bin/claude"
    '';
  };
in
{
  nixpkgs.overlays = [ llmAgentsOverlay ];

  systemd.tmpfiles.rules = [
    "d ${claudeShareDir} 0700 ${user} users -"
    "d ${claudeConfigDir} 0700 ${user} users -"
    "d ${claudeRuntimeDir} 0700 ${user} users -"
    "d ${claudeStateDir} 0700 ${user} users -"
    "d ${claudeHistoryDir} 0700 ${user} users -"
    "d ${claudeProjectsDir} 0700 ${user} users -"
    "d ${claudeSessionsDir} 0700 ${user} users -"
    "d ${claudeSecretsDir} 0700 ${user} users -"
    "d ${claudeAuthDir} 0700 ${user} users -"
    "d ${claudeCredentialsDir} 0700 ${user} users -"
  ];

  home-manager.users.${user} = {
    home.packages = [ claudePackage ];
    home.sessionVariables.CLAUDE_CONFIG_DIR = claudeConfigDir;
  };
}

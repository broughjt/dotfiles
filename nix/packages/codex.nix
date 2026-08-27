{
  lib,
  pkgs,
  codexHome ? null,
  sqliteHome ? null,
  logDirectory ? null,
}:

let
  agentToolPath = lib.makeBinPath [
    pkgs.nodejs
    pkgs.python3
  ];

  preludeLines =
    lib.optional (codexHome != null) "export CODEX_HOME=${lib.escapeShellArg codexHome}"
    ++ lib.optional (sqliteHome != null) "export CODEX_SQLITE_HOME=${lib.escapeShellArg sqliteHome}"
    ++ [ "export PATH=${lib.escapeShellArg agentToolPath}:\${PATH:-}" ];

  configFlags =
    lib.optional (
      logDirectory != null
    ) "--config ${lib.escapeShellArg "log_dir=${builtins.toJSON logDirectory}"}"
    ++ lib.optional (
      sqliteHome != null
    ) "--config ${lib.escapeShellArg "sqlite_home=${builtins.toJSON sqliteHome}"}"
    ++ [ "--config ${lib.escapeShellArg "features.apps=false"}" ];
in
pkgs.writeShellScriptBin "codex" ''
  set -euo pipefail

  ${lib.concatStringsSep "\n" preludeLines}

  exec ${pkgs.llm-agents.codex}/bin/codex \
    ${lib.concatStringsSep " \\\n  " configFlags} \
    --dangerously-bypass-approvals-and-sandbox \
    "$@"
''

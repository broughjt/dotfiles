{
  lib,
  pkgs,
  codexHome ? null,
}:

let
  agentToolPath = lib.makeBinPath [
    pkgs.nodejs
    pkgs.python3
  ];

  preludeLines =
    lib.optional (codexHome != null) "export CODEX_HOME=${lib.escapeShellArg codexHome}"
    ++ [ "export PATH=${lib.escapeShellArg agentToolPath}:\${PATH:-}" ];
in
pkgs.writeShellScriptBin "codex" ''
  set -euo pipefail

  ${lib.concatStringsSep "\n" preludeLines}

  exec ${pkgs.llm-agents.codex}/bin/codex \
    --config ${lib.escapeShellArg "features.apps=false"} \
    --dangerously-bypass-approvals-and-sandbox \
    "$@"
''

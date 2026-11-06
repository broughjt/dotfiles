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

  # Codex warns at startup unless bwrap is on PATH, even though it falls back
  # to the copy llm-agents bundles (numtide/llm-agents.nix#11406). Appending
  # it keeps a host bwrap, if any, first.
  sandboxPath = lib.makeBinPath [ pkgs.bubblewrap ];

  preludeLines =
    lib.optional (codexHome != null) "export CODEX_HOME=${lib.escapeShellArg codexHome}"
    ++ [ "export PATH=${lib.escapeShellArg agentToolPath}:\${PATH:-}" ]
    ++ lib.optional pkgs.stdenv.hostPlatform.isLinux "export PATH=$PATH:${lib.escapeShellArg sandboxPath}";
in
pkgs.writeShellScriptBin "codex" ''
  set -euo pipefail

  ${lib.concatStringsSep "\n" preludeLines}

  exec ${pkgs.llm-agents.codex}/bin/codex \
    --dangerously-bypass-approvals-and-sandbox \
    "$@"
''

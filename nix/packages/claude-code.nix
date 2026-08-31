{ lib, pkgs }:

let
  agentToolPath = lib.makeBinPath [
    pkgs.python3
  ];
in
pkgs.symlinkJoin {
  name = "claude-code-agent-tools";
  paths = [ pkgs.llm-agents.claude-code ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    rm -f "$out/bin/claude"
    makeWrapper ${pkgs.llm-agents.claude-code}/bin/claude "$out/bin/claude" \
      --prefix PATH : ${lib.escapeShellArg agentToolPath} \
      --add-flags --dangerously-skip-permissions
  '';
}

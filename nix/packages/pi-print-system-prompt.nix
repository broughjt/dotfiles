{ pkgs }:

pkgs.writeShellApplication {
  name = "pi-print-system-prompt";
  runtimeInputs = [ pkgs.nodejs ];
  text = ''
    export PI_CODING_AGENT_ROOT="${pkgs.llm-agents.pi}/lib/node_modules/@earendil-works/pi-coding-agent"
    exec node ${../../scripts/pi-print-system-prompt.mjs} "$@"
  '';
}

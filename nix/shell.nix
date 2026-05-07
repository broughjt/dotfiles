{ pkgs }:

let
  piPrintSystemPrompt = pkgs.writeShellApplication {
    name = "pi-print-system-prompt";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export PI_CODING_AGENT_ROOT="${pkgs.llm-agents.pi}/lib/node_modules/@mariozechner/pi-coding-agent"
      exec node ${../scripts/pi-print-system-prompt.mjs} "$@"
    '';
  };
in
{
  devShells.default = pkgs.mkShell {
    packages = with pkgs; [
      nil
      nixfmt
      piPrintSystemPrompt
    ];
  };
}

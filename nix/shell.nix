{ pkgs }:

let
  piPrintSystemPrompt = pkgs.writeShellApplication {
    name = "pi-print-system-prompt";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec node --input-type=module - "$@" <<'EOF'
      import {
        createAgentSession,
        SessionManager,
      } from "${pkgs.llm-agents.pi}/lib/node_modules/@mariozechner/pi-coding-agent/dist/index.js";

      const { session } = await createAgentSession({
        sessionManager: SessionManager.inMemory(),
      });

      try {
        console.log(session.systemPrompt);
      } finally {
        session.dispose();
      }
      EOF
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

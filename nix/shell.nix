{ pkgs }:

let
  piPrintSystemPromptScript = pkgs.writeText "pi-print-system-prompt.mjs" ''
    import {
      createAgentSession,
      SessionManager,
    } from "${pkgs.llm-agents.pi}/lib/node_modules/@mariozechner/pi-coding-agent/dist/index.js";

    const args = new Set(process.argv.slice(2));

    if (args.has("--help") || args.has("-h")) {
      console.log(`Usage: pi-print-system-prompt [options]

    Print Pi's resolved system prompt and active tool declarations.

    Options:
      --prompt-only  Print only the system prompt
      --tools-only   Print only tool declarations
      --all-tools    Print all configured tools, including inactive tools
      --help, -h     Show this help`);
      process.exit(0);
    }

    const { session } = await createAgentSession({
      sessionManager: SessionManager.inMemory(),
    });

    function formatToolDefinitions(tools, label) {
      const lines = [`Tool Definitions (''${tools.length} ''${label})`, ""];

      for (const tool of tools) {
        const source = tool.sourceInfo?.source ?? "unknown";
        lines.push(`name: ''${tool.name}`);
        lines.push(`  description: ''${tool.description}`);
        lines.push(`  source: ''${source}`);
        lines.push("  parameters:");
        for (const line of JSON.stringify(tool.parameters, null, 2).split("\n")) {
          lines.push(`    ''${line}`);
        }
        lines.push("");
      }

      return lines.join("\n");
    }

    try {
      const allTools = session.getAllTools();
      const activeToolNames = new Set(session.getActiveToolNames());
      const tools = args.has("--all-tools")
        ? allTools
        : allTools.filter((tool) => activeToolNames.has(tool.name));
      const toolLabel = args.has("--all-tools") ? "configured tools" : "active tools";

      if (!args.has("--tools-only")) {
        console.log(session.systemPrompt);
      }

      if (!args.has("--prompt-only")) {
        if (!args.has("--tools-only")) {
          console.log("\n────────────────────────────────────────\n");
        }
        console.log(formatToolDefinitions(tools, toolLabel));
      }
    } finally {
      session.dispose();
    }
  '';

  piPrintSystemPrompt = pkgs.writeShellApplication {
    name = "pi-print-system-prompt";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec node ${piPrintSystemPromptScript} "$@"
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

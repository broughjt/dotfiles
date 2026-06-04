/**
 * tame-shell — steer Pi away from large, chained shell commands.
 *
 * Two root-cause fixes, applied together:
 *
 * 1. Enable Pi's dedicated `grep`/`find`/`ls` tools. They ship with Pi but are
 *    inactive in the default `read,bash,edit,write` set, which is *why* Pi
 *    injects the "Use bash for file operations like ls, rg, find" guideline
 *    (it is conditional on those tools being absent — see system-prompt.ts).
 *    Activating them gives the model real alternatives to bash and makes that
 *    guideline disappear on the next prompt rebuild.
 *
 * 2. Append guidance on command shape: prefer the dedicated tools and lean on
 *    Pi's parallel tool execution instead of packing work into one command.
 *
 * Loaded automatically from ~/.pi/agent/extensions/ (see pi-coding-agent.nix).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** The tools we want active: the coding defaults plus the dedicated search/list tools. */
const DESIRED_ACTIVE_TOOLS = ["read", "bash", "edit", "write", "grep", "find", "ls"];

const SHELL_GUIDANCE = `## Shell and file-tool usage

- Prefer Pi's dedicated tools over shell commands: use \`read\` for file contents (not \`cat\`/\`head\`/\`tail\`/\`sed\`), \`grep\` to search file contents, \`find\` to locate files by name, and \`ls\` to list directories. Reach for \`bash\` to actually run programs — builds, tests, package managers, git, and other executables — not as a stand-in for those tools.
- Pi runs the tool calls within a turn concurrently. When operations are independent, emit them as separate parallel tool calls in one turn instead of packing them into a single large shell command.
- When a single bash command genuinely involves multiple steps, structure it for readability: separate the steps with labeled banners (for example \`echo "=== build ===" && cmd1 && echo "=== test ===" && cmd2\`) so the output is easy to scan. Reserve this for cases where the steps belong together (don't pad simple one-off commands with banners).`;

export default function tameShell(pi: ExtensionAPI): void {
	// Activate the dedicated search/list tools once per session. Filter against
	// the registry so an explicit `--tools` allowlist is still respected, and so
	// we never try to enable a tool that isn't available.
	pi.on("session_start", async () => {
		const available = new Set(pi.getAllTools().map((tool) => tool.name));
		const next = DESIRED_ACTIVE_TOOLS.filter((name) => available.has(name));
		pi.setActiveTools(next);
	});

	// Append the command-shape guidance for this turn. The base prompt is rebuilt
	// fresh each turn, so this does not compound across turns.
	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt: `${event.systemPrompt}\n\n${SHELL_GUIDANCE}\n`,
		};
	});
}

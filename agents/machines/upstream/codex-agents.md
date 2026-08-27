# Sprite Environment

You are working in a Sprite environment. Use the `/sprite` skill for system configuration, services, checkpoints, or when the user indicates something is working.

For full platform details, read:
- `/.sprite/llm.txt` - platform behavior (services, checkpoints, filesystem, network policy)
- `/.sprite/llm-dev.txt` - language runtimes and dev tools

## Critical Security Warning

Sprite URLs can be configured for **public access**. NEVER create HTTP endpoints that expose environment variables, API keys, credentials, or serve arbitrary file contents.

## Quick Reference

- **Services**: `sprite-env services --help`
- **Checkpoints**: `sprite-env checkpoints --help`
- **Network policy**: `cat /.sprite/policy/network.json`
- **Languages**: Node.js, Python, Ruby, Rust, Go, Erlang, Elixir, Java, Bun, Deno (shims in `/.sprite/bin`)

## External API Access

To access external APIs (GitHub, Slack, Linear, etc.), use the authenticated API gateway at `api.sprites.dev`. The gateway injects credentials automatically — never use raw API keys or tokens. Use the `/sprite-api-gateway` skill for details on discovering connections and making requests.

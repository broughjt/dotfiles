# Environment notes

This machine runs NixOS. If a command/tool is missing, use Nix rather than giving up.

Prefer ephemeral tools:

- One-off executable: `nix run nixpkgs#<package> -- <args>`
- Shell with packages: `nix shell nixpkgs#<pkg1> nixpkgs#<pkg2> -c <command> ...`
- If the project has `flake.nix`, prefer: `nix develop -c <command> ...`

Examples:

- `nix run nixpkgs#python3 -- --version`
- `nix shell nixpkgs#python3 -c python3 script.py`
- `nix shell nixpkgs#jq nixpkgs#curl -c 'curl -s URL | jq .'`

Do not assume missing tools are unavailable. Search or run them through Nix when useful.
Prefer ephemeral `nix run`/`nix shell` over permanently installing packages.

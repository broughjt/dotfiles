# User-global agent instructions

Shared by Claude Code, Codex, and Pi. Source of truth is
`agents/AGENTS.md` in the dotfiles repository; each agent reaches it
through a Nix-managed symlink, so it is immutable at runtime.

## Environment notes

This machine runs NixOS. If a command/tool is missing, use Nix rather than giving up.
For example, if a specialized CLI, language runtime, or library is missing, run it through Nix instead of assuming it is unavailable.

Prefer ephemeral tools:

- If the project has `flake.nix`, prefer: `nix develop -c <command> ...`
- One-off executable: `nix run nixpkgs#<package> -- <args>`
- Shell with packages: `nix shell nixpkgs#<pkg1> nixpkgs#<pkg2> -c <command> ...`

Examples:

- `nix run nixpkgs#shellcheck -- --version`
- `nix shell nixpkgs#poppler-utils -c pdftotext document.pdf`
- `nix shell nixpkgs#imagemagick nixpkgs#exiftool -c 'magick identify image.png && exiftool image.png'`

Do not assume missing tools are unavailable. Search or run them through Nix when useful.
Prefer ephemeral `nix run`/`nix shell` over permanently installing packages.

## Git

Work you implement gets reviewed before it lands.

- Work on a feature branch, one per reviewable unit.
- Commit your implementation as a single **proposal commit** with a real
  message. The review anchors to that SHA.
- Fixes from review land as **separate commits on top** — never amend the
  proposal — so `git diff <proposal>..HEAD` stays "everything review changed".
- Do not push. I collapse the stack with `git reset --soft <base>` and write
  the final message before pushing.

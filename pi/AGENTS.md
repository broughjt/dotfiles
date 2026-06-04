# Environment notes

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

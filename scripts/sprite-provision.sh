#!/usr/bin/env bash
set -euo pipefail

# Provision a sprite with my preferred settings.

# Substituted with the payload store path by nix/packages/scripts.nix, which is
# why this only runs as a flake app.
PAYLOAD="@PAYLOAD@"
REMOTE_DIRECTORY=/tmp/sprite-provision

main() {
  case "${1-}" in
    "")
      usage >&2
      exit 1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
  esac

  [ "$#" -eq 1 ] || die "expected one sprite name, got $#"
  [ -d "$PAYLOAD" ] || die "no payload at $PAYLOAD; run 'nix run .#spriteProvision'"
  command -v sprite > /dev/null || die "sprite is not on PATH"

  local name="$1"

  info "provisioning sprite $name"
  # Cleared rather than just overwritten to avoid files which are removed by
  # subsequent version sticking around.
  info "pushing the payload to $REMOTE_DIRECTORY"
  sprite exec -s "$name" -- rm -rf "$REMOTE_DIRECTORY"
  # push lists every file it copied, which duplicates what the in-sprite half
  # reports as it installs them.
  sprite file push -s "$name" --recursive --parents "$PAYLOAD" "$REMOTE_DIRECTORY" > /dev/null
  sprite exec -s "$name" -- bash "$REMOTE_DIRECTORY/in-sprite.sh"
}

usage() {
  cat <<EOF
Usage: sprite-provision SPRITE

Provision SPRITE with my preferred configuration. Every step is idempotent, so
re-running after a change to this script applies just the difference.

Steps:
  - install single-user Nix, with flakes enabled, no channels, and
    unfree packages allowed
  - activate the standalone Home Manager configuration from this exact
    dotfiles revision
  - write the agent instructions to ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md,
    refusing to run if the base image's own instructions have drifted from the
    copy vendored in agents/machines/upstream/
  - sync agents/skills into both agent skill directories, leaving the base
    image's own skills alone
  - write ~/.gitconfig and a fish conf.d drop-in

Arguments:
  SPRITE  name of the sprite, as shown by 'sprite list'

Options:
  -h, --help  Show this help.

'sprite' must be on PATH.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

info() {
  echo "info: $*"
}

main "$@"

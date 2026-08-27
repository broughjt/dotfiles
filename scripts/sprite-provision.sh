#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Nix in a sprite.

# Substituted with the store path by nix/packages/scripts.nix, which is why
# this only runs as a flake app.
IN_SPRITE_SCRIPT="@IN_SPRITE_SCRIPT@"
REMOTE_DIRECTORY=/tmp/sprite-provision
REMOTE_SCRIPT="$REMOTE_DIRECTORY/in-sprite.sh"

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
  [ -f "$IN_SPRITE_SCRIPT" ] || die "no in-sprite script at $IN_SPRITE_SCRIPT; run 'nix run .#spriteProvision'"
  command -v sprite > /dev/null || die "sprite is not on PATH"

  local name="$1"

  info "provisioning sprite $name"
  # Cleared rather than just overwritten to avoid files which are removed by
  # subsequent version sticking around.
  info "pushing the bootstrap script to $REMOTE_SCRIPT"
  sprite exec -s "$name" -- rm -rf "$REMOTE_DIRECTORY"
  sprite file push -s "$name" --parents "$IN_SPRITE_SCRIPT" "$REMOTE_SCRIPT" > /dev/null
  sprite exec -s "$name" -- bash "$REMOTE_SCRIPT"
}

usage() {
  cat <<EOF
Usage: sprite-provision SPRITE

Bootstrap Nix in SPRITE. Every step is idempotent, so re-running after a change
to this script applies just the difference.

Steps:
  - install single-user Nix, with flakes enabled, no channels, and
    unfree packages allowed

After pushing a reviewed dotfiles commit, activate its Home Manager generation:

  sprite exec -s SPRITE -- nix run github:broughjt/dotfiles/REVISION#spriteHomeSwitch

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

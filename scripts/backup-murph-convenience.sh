#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
backup-murph-convenience: create an unencrypted murph convenience backup.

Usage:
  sudo scripts/backup-murph-convenience.sh /path/to/usb

This intentionally excludes core secrets. It is for state that is useful but not
required for identity recovery, such as repositories, share/scratch data,
browser profile, known_hosts, fish history, Pi sessions/settings, and direnv trust decisions.

The archive is unencrypted for convenience. Review the path list before putting
it on an untrusted USB: browser profiles and shell history can still be private.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

case "${1-}" in
  ""|-h|--help)
    usage
    [ "${1-}" = "" ] && exit 1 || exit 0
    ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  die "run as root so /persist is readable"
fi

command -v tar >/dev/null || die "tar is not on PATH"
command -v sha256sum >/dev/null || die "sha256sum is not on PATH"

DEST_DIR="$1"
[ -d "$DEST_DIR" ] || die "destination is not a directory: $DEST_DIR"
[ -d /persist ] || die "/persist does not exist"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
host="$(hostname)"
base="murph-convenience-${host}-${timestamp}"
archive="$DEST_DIR/${base}.tar.gz"
manifest="$DEST_DIR/${base}.MANIFEST.txt"

candidates=(
  "home/jackson/repositories"
  "home/jackson/share"
  "home/jackson/scratch"
  "home/jackson/.mozilla/firefox"
  "home/jackson/local/hacks/ssh/known_hosts"
  "home/jackson/local/hacks/fish/fish_history"
  "home/jackson/local/hacks/gh/hosts"
  "home/jackson/local/hacks/tmux/resurrect"
  "home/jackson/local/hacks/pi/settings"
  "home/jackson/local/state/pi/sessions"
  "home/jackson/local/share/direnv/allow"
  "home/jackson/local/share/direnv/deny"
)

paths=()
for path in "${candidates[@]}"; do
  if [ -e "/persist/$path" ]; then
    paths+=("$path")
  else
    echo "warning: skipping missing /persist/$path" >&2
  fi
done

[ "${#paths[@]}" -gt 0 ] || die "no backup paths exist"

{
  echo "murph convenience backup"
  echo "created_utc=$timestamp"
  echo "host=$host"
  if command -v git >/dev/null && [ -d /home/jackson/repositories/dotfiles/.git ]; then
    echo "dotfiles_rev=$(git -C /home/jackson/repositories/dotfiles rev-parse HEAD 2>/dev/null || true)"
  fi
  echo
  echo "archive=$(basename "$archive")"
  echo "archive_contents_relative_to=/persist"
  echo "encrypted=false"
  echo
  echo "paths:"
  printf '  %s\n' "${paths[@]}"
  echo
  echo "notes:"
  echo "  - This archive is not encrypted."
  echo "  - It may still contain private browsing, shell, project, and personal-file state."
  echo "  - Extract into /mnt/persist during install."
} > "$manifest"

printf 'Creating convenience archive: %s\n' "$archive"
tar \
  --create \
  --gzip \
  --file "$archive" \
  --directory /persist \
  "${paths[@]}"

sha256sum "$archive" >> "$manifest"
chmod 0644 "$archive" "$manifest"

if [ -n "${SUDO_USER-}" ]; then
  chown "$SUDO_USER" "$archive" "$manifest" 2>/dev/null || true
fi

printf 'Wrote:\n  %s\n  %s\n' "$archive" "$manifest"

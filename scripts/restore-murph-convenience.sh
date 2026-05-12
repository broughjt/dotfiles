#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
restore-murph-convenience: restore an unencrypted murph convenience archive.

Usage:
  sudo restore-murph-convenience /path/to/murph-convenience-*.tar.gz [mountpoint]

Arguments:
  archive     Unencrypted archive created by backup-murph-convenience.
  mountpoint  Installed system mountpoint. Defaults to /mnt.

The archive is extracted into <mountpoint>/persist.
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
  die "run as root so restored files can be owned and permissioned correctly"
fi

command -v tar >/dev/null || die "tar is not on PATH"

ARCHIVE="$1"
MOUNTPOINT="${2-/mnt}"
PERSIST="$MOUNTPOINT/persist"

[ -f "$ARCHIVE" ] || die "archive does not exist: $ARCHIVE"
[ -d "$PERSIST" ] || die "persist directory does not exist: $PERSIST"

echo "info: extracting $ARCHIVE into $PERSIST"
tar --extract --gzip --file "$ARCHIVE" --directory "$PERSIST"

# Normalize ownership and permissions after extraction. Convenience state is not
# secret as a bundle, but individual files such as known_hosts, fish_history,
# and direnv trust records should still land with the modes expected by the
# impermanence configuration.
chown -R 1000:100 "$PERSIST/home/jackson" 2>/dev/null || true

chmod 0700 \
  "$PERSIST/home/jackson/local/hacks/fish/fish_history" \
  "$PERSIST/home/jackson/local/hacks/ssh/known_hosts" \
  "$PERSIST/home/jackson/local/hacks/gh/hosts" \
  "$PERSIST/home/jackson/local/hacks/tmux/resurrect" \
  "$PERSIST/home/jackson/local/hacks/tmux/resurrect/resurrect" \
  "$PERSIST/home/jackson/local/hacks/emacs/projects" \
  "$PERSIST/home/jackson/local/hacks/pi/settings" \
  "$PERSIST/home/jackson/local/state/emacs/backups" \
  "$PERSIST/home/jackson/local/state/emacs/auto-saves" \
  "$PERSIST/home/jackson/local/state/pi/sessions" \
  "$PERSIST/home/jackson/local/state/pi/mcp" \
  "$PERSIST/home/jackson/local/share/direnv/allow" \
  "$PERSIST/home/jackson/local/share/direnv/deny" \
  2>/dev/null || true

chmod 0600 \
  "$PERSIST/home/jackson/local/hacks/ssh/known_hosts/known_hosts" \
  "$PERSIST/home/jackson/local/hacks/fish/fish_history/fish_history" \
  "$PERSIST/home/jackson/local/hacks/gh/hosts/hosts.yml" \
  "$PERSIST/home/jackson/local/hacks/emacs/projects/projects.eld" \
  "$PERSIST/home/jackson/local/hacks/pi/settings/settings.json" \
  "$PERSIST/home/jackson/local/state/pi/mcp/mcp-cache.json" \
  "$PERSIST/home/jackson/local/state/pi/mcp/mcp-onboarding.json" \
  "$PERSIST/home/jackson/local/state/pi/mcp/settings-package-seeded" \
  2>/dev/null || true

echo "info: convenience restore complete"

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
backup-murph-secrets: create an encrypted murph secrets backup.

Usage:
  sudo scripts/backup-murph-secrets.sh /path/to/usb

The output archive is encrypted with age --passphrase and contains only the
state needed to recover identities/secrets on reinstall:

  /persist/etc/ssh
  /persist/home/jackson/local/secrets/ssh
  /persist/home/jackson/local/secrets/gnupg
  /persist/home/jackson/local/state/gnupg
  /persist/home/jackson/local/share/keyrings
  /persist/home/jackson/local/secrets/pi/auth
  /persist/home/jackson/local/secrets/pi/mcp
  /persist/home/jackson/local/secrets/pi/mcp-oauth

The archive is suitable for extraction into /mnt/persist during install.
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
  die "run as root so host SSH keys and all secret files are readable"
fi

command -v age >/dev/null || die "age is not on PATH"
command -v tar >/dev/null || die "tar is not on PATH"
command -v sha256sum >/dev/null || die "sha256sum is not on PATH"

DEST_DIR="$1"
[ -d "$DEST_DIR" ] || die "destination is not a directory: $DEST_DIR"
[ -d /persist ] || die "/persist does not exist"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
host="$(hostname)"
base="murph-secrets-${host}-${timestamp}"
archive="$DEST_DIR/${base}.tar.gz.age"
manifest="$DEST_DIR/${base}.MANIFEST.txt"

candidates=(
  "etc/ssh"
  "home/jackson/local/secrets/ssh"
  "home/jackson/local/secrets/pi/auth"
  "home/jackson/local/secrets/pi/mcp"
  "home/jackson/local/secrets/pi/mcp-oauth"
  "home/jackson/local/secrets/gnupg"
  "home/jackson/local/state/gnupg"
  "home/jackson/local/share/keyrings"
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
  echo "murph secrets backup"
  echo "created_utc=$timestamp"
  echo "host=$host"
  if command -v git >/dev/null && [ -d /home/jackson/repositories/dotfiles/.git ]; then
    echo "dotfiles_rev=$(git -C /home/jackson/repositories/dotfiles rev-parse HEAD 2>/dev/null || true)"
  fi
  echo
  echo "encrypted_archive=$(basename "$archive")"
  echo "archive_contents_relative_to=/persist"
  echo
  echo "paths:"
  printf '  %s\n' "${paths[@]}"
  echo
  echo "notes:"
  echo "  - Encrypted with age --passphrase."
  echo "  - Extract into /mnt/persist during install."
} > "$manifest"

printf 'Creating encrypted archive: %s\n' "$archive"
tar \
  --create \
  --gzip \
  --file - \
  --directory /persist \
  "${paths[@]}" \
  | age --passphrase --output "$archive"

sha256sum "$archive" >> "$manifest"
chmod 0600 "$archive"
chmod 0644 "$manifest"

if [ -n "${SUDO_USER-}" ]; then
  chown "$SUDO_USER" "$archive" "$manifest" 2>/dev/null || true
fi

printf 'Wrote:\n  %s\n  %s\n' "$archive" "$manifest"

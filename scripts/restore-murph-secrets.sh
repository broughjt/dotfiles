#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
restore-murph-secrets: restore an encrypted murph secrets archive.

Usage:
  sudo restore-murph-secrets /path/to/murph-secrets-*.tar.gz.age [mountpoint]

Arguments:
  archive     Encrypted archive created by backup-murph-secrets.
  mountpoint  Installed system mountpoint. Defaults to /mnt.

The archive is decrypted with age --decrypt and extracted into
<mountpoint>/persist.
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

command -v age >/dev/null || die "age is not on PATH"
command -v tar >/dev/null || die "tar is not on PATH"

ARCHIVE="$1"
MOUNTPOINT="${2-/mnt}"
PERSIST="$MOUNTPOINT/persist"

[ -f "$ARCHIVE" ] || die "archive does not exist: $ARCHIVE"
[ -d "$PERSIST" ] || die "persist directory does not exist: $PERSIST"

echo "info: decrypting and extracting $ARCHIVE into $PERSIST"
age --decrypt "$ARCHIVE" | tar --extract --gzip --directory "$PERSIST"

# Normalize ownership and permissions after extraction. The archive may have
# been created on a live system with correct metadata already, but reinstall
# restore should not depend on tar preserving every mode exactly or on numeric
# owners matching names in the installer environment.
chown -R 1000:100 "$PERSIST/home/jackson" 2>/dev/null || true

GNUPG_DIR="$PERSIST/home/jackson/local/share/gnupg"
if [ -d "$GNUPG_DIR" ]; then
  # These files are runtime-only or declarative in the installed system. Remove
  # them even when restoring an older archive that still contained them.
  rm -f \
    "$GNUPG_DIR"/S.* \
    "$GNUPG_DIR"/.#lk* \
    "$GNUPG_DIR"/*.lock \
    "$GNUPG_DIR"/*/.#lk* \
    "$GNUPG_DIR"/*/*.lock \
    "$GNUPG_DIR"/random_seed \
    "$GNUPG_DIR"/gpg.conf \
    "$GNUPG_DIR"/gpg-agent.conf \
    2>/dev/null || true
  rm -rf "$GNUPG_DIR/crls.d"
fi

chmod 0700 \
  "$PERSIST/home/jackson/local/secrets" \
  "$PERSIST/home/jackson/local/secrets/ssh" \
  "$PERSIST/home/jackson/local/secrets/pi" \
  "$PERSIST/home/jackson/local/secrets/pi/auth" \
  "$PERSIST/home/jackson/local/share/gnupg" \
  "$PERSIST/home/jackson/local/share/keyrings" \
  2>/dev/null || true

chmod 0600 "$PERSIST/home/jackson/local/secrets/ssh/id_ed25519" 2>/dev/null || true
chmod 0644 "$PERSIST/home/jackson/local/secrets/ssh/id_ed25519.pub" 2>/dev/null || true
chmod 0600 "$PERSIST/home/jackson/local/secrets/pi/auth/auth.json" 2>/dev/null || true

if [ -d "$PERSIST/etc/ssh" ]; then
  chown -R root:root "$PERSIST/etc/ssh"
  chmod 0600 "$PERSIST/etc/ssh"/ssh_host_*_key 2>/dev/null || true
  chmod 0644 "$PERSIST/etc/ssh"/ssh_host_*_key.pub 2>/dev/null || true
fi

echo "info: secrets restore complete"

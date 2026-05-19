#!/usr/bin/env bash
set -euo pipefail

DEFAULT_ISO_URL="https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso"
ISO_URL="${NIXOS_ISO_URL:-$DEFAULT_ISO_URL}"
TMPDIR="${NIXOS_ISO_TMPDIR:-/tmp/nixos-installer}"

usage() {
  cat <<EOF
Usage: flash-nixos-installer DISK

Download and flash the NixOS minimal installer ISO to a USB disk.

Arguments:
  DISK  Whole USB disk device, e.g. /dev/sdX or /dev/disk/by-id/usb-...

Environment:
  NIXOS_ISO_URL     ISO URL to download
                    default: $DEFAULT_ISO_URL
  NIXOS_ISO_TMPDIR  temporary download directory
                    default: /tmp/nixos-installer

This destroys all data on DISK. Pass the whole disk, not a partition.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  die "run as root so the USB disk can be unmounted, written, and ejected"
fi

TARGET=$1
if [ ! -e "$TARGET" ]; then
  die "target does not exist: $TARGET"
fi

DISK=$(readlink -f -- "$TARGET")
if [ -z "$DISK" ] || [ ! -b "$DISK" ]; then
  die "target is not a block device: $TARGET"
fi

TYPE=$(lsblk --noheadings --nodeps --output TYPE -- "$DISK" | tr -d '[:space:]')
if [ "$TYPE" = "part" ]; then
  die "$TARGET resolves to a partition; pass the whole USB disk instead"
fi
if [ "$TYPE" != "disk" ]; then
  die "$TARGET resolves to $TYPE, not a disk"
fi

TRAN=$(lsblk --noheadings --nodeps --output TRAN -- "$DISK" 2>/dev/null | tr -d '[:space:]' || true)
REMOVABLE=$(lsblk --noheadings --nodeps --output RM -- "$DISK" | tr -d '[:space:]')
if [ "$TRAN" != "usb" ] && [ "$REMOVABLE" != "1" ]; then
  die "$DISK does not look like a removable USB disk (TRAN=$TRAN RM=$REMOVABLE)"
fi

mkdir -p "$TMPDIR"
ISO_PATH="$TMPDIR/$(basename "$ISO_URL")"
PARTIAL_ISO_PATH="$ISO_PATH.part"
trap 'rm -f "$PARTIAL_ISO_PATH"' EXIT

cat <<EOF
About to download and flash the NixOS installer.

ISO URL: $ISO_URL
ISO path: $ISO_PATH
Target:   $DISK

Target device details:
EOF
lsblk --output NAME,PATH,SIZE,TYPE,TRAN,RM,MODEL,MOUNTPOINTS -- "$DISK"
cat <<EOF

WARNING: this will destroy all data on $DISK.
EOF

read -r -p "Type the exact target device path ($DISK) to continue: " CONFIRM
if [ "$CONFIRM" != "$DISK" ]; then
  die "confirmation did not match; aborted"
fi

echo "info: downloading ISO to $ISO_PATH"
curl --fail --location --show-error --output "$PARTIAL_ISO_PATH" "$ISO_URL"
mv -f "$PARTIAL_ISO_PATH" "$ISO_PATH"

echo "info: unmounting filesystems on $DISK"
while IFS= read -r name; do
  [ -n "$name" ] || continue
  umount "/dev/$name" 2>/dev/null || true
done < <(lsblk --list --noheadings --output NAME -- "$DISK")

echo "info: flashing $ISO_PATH to $DISK"
dd if="$ISO_PATH" of="$DISK" bs=4M status=progress conv=fsync
sync

if eject "$DISK" 2>/dev/null; then
  echo "info: ejected $DISK"
else
  echo "warning: could not eject $DISK; remove it manually after activity stops" >&2
fi

echo "info: done"

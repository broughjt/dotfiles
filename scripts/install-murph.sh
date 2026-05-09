#!/usr/bin/env bash
set -euo pipefail

DISK="/dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380"
INSTALL_FLAKE="@DOTFILES_FLAKE@"
MOUNTPOINT="/mnt"

usage() {
  cat <<EOF
install-murph: destructive installer for the murph NixOS host.

Usage:
  nix run github:broughjt/dotfiles#installMurph

This erases murph's configured NVMe and installs this flake's #murph-install.

Options:
  -h, --help              Show this help.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

warn() {
  echo "warning: $*" >&2
}

case "${1-}" in
  "")
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    die "unknown option: $1"
    ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  die "run as root. From the installer, use 'sudo -i' first, then run install-murph."
fi

export NIX_CONFIG="${NIX_CONFIG-}
experimental-features = nix-command flakes
accept-flake-config = true
"

WORKDIR="$(mktemp -d -t murph-install.XXXXXX)"
PASSWORD_DIR="$WORKDIR/passwords"
MACHINE_ID_DIR="$WORKDIR/machine-id"
cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

print_preflight() {
  info "install target"
  cat <<EOF
flake:      ${INSTALL_FLAKE}#murph-install
disk:       ${DISK}
mountpoint: ${MOUNTPOINT}
EOF
  echo

  info "installer resources"
  df -h /nix /tmp /run 2>/dev/null || true
  free -h 2>/dev/null || true
  echo

  info "block devices"
  lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
  echo
}

make_password_hash() {
  local user="$1"
  local out="$2"

  while true; do
    printf '%s password: ' "$user"
    read -rs p1
    echo
    printf 'confirm %s password: ' "$user"
    read -rs p2
    echo

    if [ "$p1" = "$p2" ]; then
      printf '%s\n' "$p1" | mkpasswd -m yescrypt --stdin > "$out"
      chmod 600 "$out"
      unset p1 p2
      return 0
    fi

    unset p1 p2
    echo "passwords did not match; try again" >&2
  done
}

generate_persistent_inputs() {
  info "generating yescrypt password hash files"
  mkdir -p "$PASSWORD_DIR"
  make_password_hash jackson "$PASSWORD_DIR/jackson"
  make_password_hash root "$PASSWORD_DIR/root"

  info "generating persistent machine-id"
  mkdir -p "$MACHINE_ID_DIR"
  uuidgen -r | tr -d '-' > "$MACHINE_ID_DIR/machine-id"
  chmod 444 "$MACHINE_ID_DIR/machine-id"
}

run_preflight_checks() {
  command -v disko-install >/dev/null || die "disko-install is not on PATH"
  command -v mkpasswd >/dev/null || die "mkpasswd is not on PATH"
  command -v zfs >/dev/null || die "zfs is not on PATH"
  command -v zpool >/dev/null || die "zpool is not on PATH"

  [ -e "$DISK" ] || die "target disk does not exist: $DISK"

  info "loading ZFS kernel module"
  modprobe zfs || die "failed to load zfs module"

  if zpool list -H zroot >/dev/null 2>&1; then
    warn "zpool zroot is already imported; install will attempt to export/recreate it"
  fi
}

run_disko_install() {
  info "running disko-install"
  disko-install \
    --write-efi-boot-entries \
    --extra-files "$PASSWORD_DIR" /persist/etc/passwords \
    --extra-files "$MACHINE_ID_DIR/machine-id" /persist/etc/machine-id \
    --flake "${INSTALL_FLAKE}#murph-install" \
    --disk main "$DISK"
}

normalize_target_mount() {
  info "normalizing target mount at ${MOUNTPOINT}"

  umount -R "${MOUNTPOINT}/disko-install-root" 2>/dev/null || true
  umount "${MOUNTPOINT}/boot" 2>/dev/null || true

  if zpool list -H zroot >/dev/null 2>&1; then
    zfs unmount zroot/enc/safe/persist 2>/dev/null || true
    zfs unmount zroot/enc/local/docker 2>/dev/null || true
    zfs unmount zroot/enc/local/nix 2>/dev/null || true
    zfs unmount zroot/enc/local/root 2>/dev/null || true
    zpool export zroot 2>/dev/null || true
  fi

  zpool import -f -N -R "$MOUNTPOINT" zroot

  if [ "$(zfs get -H -o value keystatus zroot/enc)" != "available" ]; then
    info "loading ZFS encryption key for zroot/enc"
    zfs load-key zroot/enc
  fi

  zfs mount zroot/enc/local/root
  zfs mount zroot/enc/local/nix
  zfs mount zroot/enc/local/docker
  zfs mount zroot/enc/safe/persist

  mkdir -p "${MOUNTPOINT}/boot"
  mount /dev/disk/by-label/ESP "${MOUNTPOINT}/boot"

  findmnt -R "$MOUNTPOINT"
}

print_next_steps() {
  cat <<EOF

Install finished. The target is still mounted at ${MOUNTPOINT}.

Before rebooting, mount your backup USB and restore preserved host keys and
personal state into ${MOUNTPOINT}/persist. Adjust /path/to/backup as needed.

Required/recommended state:

   mkdir -p ${MOUNTPOINT}/persist/etc/ssh
   rsync -a /path/to/backup/murph-ssh-host-keys/ssh_host_* ${MOUNTPOINT}/persist/etc/ssh/
   chmod 600 ${MOUNTPOINT}/persist/etc/ssh/ssh_host_*_key
   chmod 644 ${MOUNTPOINT}/persist/etc/ssh/ssh_host_*_key.pub

   mkdir -p ${MOUNTPOINT}/persist/home/jackson/.local/share ${MOUNTPOINT}/persist/home/jackson/.config
   rsync -a /path/to/backup/jackson/repositories/ ${MOUNTPOINT}/persist/home/jackson/repositories/
   rsync -a /path/to/backup/jackson/.ssh/ ${MOUNTPOINT}/persist/home/jackson/.ssh/
   rsync -a --exclude 'S.gpg-agent*' /path/to/backup/jackson/.local/share/gnupg/ ${MOUNTPOINT}/persist/home/jackson/.local/share/gnupg/
   rsync -a /path/to/backup/jackson/.config/gh/ ${MOUNTPOINT}/persist/home/jackson/.config/gh/

Optional extra persisted home state:

   rsync -a /path/to/backup/jackson/local/ ${MOUNTPOINT}/persist/home/jackson/local/
   rsync -a /path/to/backup/jackson/scratch/ ${MOUNTPOINT}/persist/home/jackson/scratch/
   rsync -a /path/to/backup/jackson/share/ ${MOUNTPOINT}/persist/home/jackson/share/
   rsync -a /path/to/backup/jackson/.mozilla/firefox/ ${MOUNTPOINT}/persist/home/jackson/.mozilla/firefox/

Fix ownership/permissions, then unmount and reboot:

   chown -R 1000:100 ${MOUNTPOINT}/persist/home/jackson
   chmod 700 ${MOUNTPOINT}/persist/home/jackson/.ssh ${MOUNTPOINT}/persist/home/jackson/.local/share/gnupg
   umount -R ${MOUNTPOINT}
   zpool export zroot
   reboot

After first boot, switch from the bootstrap profile to the full workstation profile:

   sudo nixos-rebuild switch --flake ~/repositories/dotfiles#murph

Then verify persistence/rollback:

   findmnt /persist
   findmnt /nix
   findmnt /var/lib/docker
   zfs list
   zfs list -t snapshot
EOF
}

print_preflight
run_preflight_checks
generate_persistent_inputs
run_disko_install
normalize_target_mount
print_next_steps

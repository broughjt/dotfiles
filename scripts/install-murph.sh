#!/usr/bin/env bash
set -euo pipefail

DEFAULT_DISK="/dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380"
DISK="${MURPH_DISK:-$DEFAULT_DISK}"
INSTALL_FLAKE="${MURPH_INSTALL_FLAKE:-${DOTFILES_FLAKE:-github:broughjt/dotfiles}}"
INSTALL_ATTR="${MURPH_INSTALL_ATTR:-murph-install}"
MOUNTPOINT="${MURPH_MOUNTPOINT:-/mnt}"
SSH_HOST_KEYS_DIR="${MURPH_SSH_HOST_KEYS_DIR:-}"
SKIP_CONFIRM="${MURPH_SKIP_CONFIRM:-0}"
KEEP_MOUNTED="${MURPH_KEEP_MOUNTED:-0}"

usage() {
  cat <<'EOF'
installMurph: destructive installer for the murph NixOS host.

Usage:
  nix run github:broughjt/dotfiles#installMurph -- [options]

Options:
  --disk PATH             Target disk to erase. Defaults to murph's NVMe by-id path.
  --flake REF             Flake ref/path containing #murph-install. Defaults to this flake.
  --attr NAME             NixOS configuration attr. Default: murph-install.
  --mountpoint PATH       Target mountpoint for post-install normalization. Default: /mnt.
  --ssh-host-keys PATH    Directory containing preserved ssh_host_* files to copy.
  --yes                   Skip the destructive confirmation prompt.
  --keep-mounted          Leave target mounted at the end for manual inspection/copying.
  -h, --help              Show this help.

Environment overrides:
  MURPH_DISK, MURPH_INSTALL_FLAKE, MURPH_INSTALL_ATTR, MURPH_MOUNTPOINT,
  MURPH_SSH_HOST_KEYS_DIR, MURPH_SKIP_CONFIRM=1, MURPH_KEEP_MOUNTED=1
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

while [ "$#" -gt 0 ]; do
  case "$1" in
    --disk)
      [ "$#" -ge 2 ] || die "--disk requires a path"
      DISK="$2"
      shift 2
      ;;
    --flake)
      [ "$#" -ge 2 ] || die "--flake requires a flake ref/path"
      INSTALL_FLAKE="$2"
      shift 2
      ;;
    --attr)
      [ "$#" -ge 2 ] || die "--attr requires a configuration name"
      INSTALL_ATTR="$2"
      shift 2
      ;;
    --mountpoint)
      [ "$#" -ge 2 ] || die "--mountpoint requires a path"
      MOUNTPOINT="$2"
      shift 2
      ;;
    --ssh-host-keys)
      [ "$#" -ge 2 ] || die "--ssh-host-keys requires a path"
      SSH_HOST_KEYS_DIR="$2"
      shift 2
      ;;
    --yes)
      SKIP_CONFIRM=1
      shift
      ;;
    --keep-mounted)
      KEEP_MOUNTED=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
 done

if [ "$(id -u)" -ne 0 ]; then
  die "run as root. From the installer, use 'sudo -i' first, then run installMurph."
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
flake:      ${INSTALL_FLAKE}#${INSTALL_ATTR}
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

confirm_destructive_install() {
  [ "$SKIP_CONFIRM" = 1 ] && return 0

  cat <<EOF
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
This will ERASE the target disk and install murph from scratch:

  ${DISK}

It will create encrypted ZFS datasets, install ${INSTALL_FLAKE}#${INSTALL_ATTR},
and write new persistent password hashes and machine-id into /persist.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EOF
  echo
  printf 'Type exactly "erase murph" to continue: '
  read -r answer
  [ "$answer" = "erase murph" ] || die "confirmation did not match; aborting"
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
    --flake "${INSTALL_FLAKE}#${INSTALL_ATTR}" \
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

copy_ssh_host_keys() {
  if [ -z "$SSH_HOST_KEYS_DIR" ] && [ -t 0 ]; then
    echo
    echo "If you have preserved SSH host keys, enter the directory containing ssh_host_* files."
    echo "Leave blank to skip; the installed system will generate new host keys."
    printf 'SSH host key directory: '
    read -r SSH_HOST_KEYS_DIR
  fi

  [ -n "$SSH_HOST_KEYS_DIR" ] || return 0
  [ -d "$SSH_HOST_KEYS_DIR" ] || die "SSH host key directory does not exist: $SSH_HOST_KEYS_DIR"

  shopt -s nullglob
  local keys=("$SSH_HOST_KEYS_DIR"/ssh_host_*)
  shopt -u nullglob
  [ "${#keys[@]}" -gt 0 ] || die "no ssh_host_* files found in $SSH_HOST_KEYS_DIR"

  info "copying preserved SSH host keys"
  mkdir -p "${MOUNTPOINT}/persist/etc/ssh"
  cp -a "${keys[@]}" "${MOUNTPOINT}/persist/etc/ssh/"
  chmod 600 "${MOUNTPOINT}"/persist/etc/ssh/ssh_host_*_key 2>/dev/null || true
  chmod 644 "${MOUNTPOINT}"/persist/etc/ssh/ssh_host_*_key.pub 2>/dev/null || true
}

finish_mounts() {
  if [ "$KEEP_MOUNTED" = 1 ]; then
    warn "leaving target mounted at ${MOUNTPOINT} because --keep-mounted was supplied"
    return 0
  fi

  if [ -t 0 ]; then
    echo
    printf 'Unmount target and export zroot now? [Y/n] '
    read -r answer
    case "$answer" in
      n|N|no|NO|No)
        warn "leaving target mounted at ${MOUNTPOINT}"
        return 0
        ;;
    esac
  fi

  info "unmounting target and exporting zroot"
  umount -R "$MOUNTPOINT" 2>/dev/null || true
  zpool export zroot 2>/dev/null || true
}

print_next_steps() {
  cat <<'EOF'

Install finished.

Next manual steps:

1. Reboot into the installed bootstrap system.

2. If needed, mount your backup USB and restore personal state:

   rsync -a /mnt/murph-home-backup-usb/jackson/repositories/ ~/repositories/
   rsync -a /mnt/murph-home-backup-usb/jackson/.ssh/ ~/.ssh/
   rsync -a /mnt/murph-home-backup-usb/jackson/.local/share/gnupg/ ~/.local/share/gnupg/
   rsync -a /mnt/murph-home-backup-usb/jackson/.config/gh/ ~/.config/gh/

3. Switch from the bootstrap profile to the full workstation profile:

   sudo nixos-rebuild switch --flake ~/repositories/dotfiles#murph

4. Verify persistence/rollback:

   findmnt /persist
   findmnt /nix
   findmnt /var/lib/docker
   zfs list
   zfs list -t snapshot

5. Restore additional persisted home directories as desired:

   rsync -a /mnt/murph-home-backup-usb/jackson/local/ ~/local/
   rsync -a /mnt/murph-home-backup-usb/jackson/scratch/ ~/scratch/
   rsync -a /mnt/murph-home-backup-usb/jackson/share/ ~/share/
   rsync -a /mnt/murph-home-backup-usb/jackson/.mozilla/firefox/ ~/.mozilla/firefox/
EOF
}

print_preflight
run_preflight_checks
confirm_destructive_install
generate_persistent_inputs
run_disko_install
normalize_target_mount
copy_ssh_host_keys
finish_mounts
print_next_steps

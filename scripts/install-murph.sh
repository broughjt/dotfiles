#!/usr/bin/env bash
set -euo pipefail

DISK="/dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380"
INSTALL_FLAKE="@DOTFILES_FLAKE@"
MOUNTPOINT="/mnt"

usage() {
  cat <<EOF
install-murph: destructive installer for murph.

Usage:
  nix run github:broughjt/dotfiles#installMurph

This erases the hard drives and installs the murph-install NixOS configuration.

Options:
  -h, --help              Show this help.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
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
  die "run as root. Invoke with 'sudo' or run 'sudo -i' first."
fi

# Ensure the installer has flakes enabled even when invoked from a stock NixOS
# installer environment.
export NIX_CONFIG="${NIX_CONFIG-}
experimental-features = nix-command flakes
accept-flake-config = true
"

# Create temporary files that disko-install will copy into /persist. They are
# intentionally kept outside the repository and created during the installation 
# process so password hashes never have to be committed.
WORKDIR="$(mktemp -d -t murph-install.XXXXXX)"
PASSWORD_DIR="$WORKDIR/passwords"
MACHINE_ID_DIR="$WORKDIR/machine-id"
trap 'rm -rf "$WORKDIR"' EXIT

# Print useful context before the destructive install.
echo "info: install target"
cat <<EOF
flake:      ${INSTALL_FLAKE}#murph-install
disk:       ${DISK}
mountpoint: ${MOUNTPOINT}
EOF
echo

echo "info: installer resources"
df -h /nix /tmp /run 2>/dev/null || true
free -h 2>/dev/null || true
echo

echo "info: block devices"
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
echo

# Fail early if the installer environment is missing anything critical.
command -v disko-install >/dev/null || die "disko-install is not on PATH"
command -v mkpasswd >/dev/null || die "mkpasswd is not on PATH"
command -v zfs >/dev/null || die "zfs is not on PATH"
command -v zpool >/dev/null || die "zpool is not on PATH"
[ -e "$DISK" ] || die "target disk does not exist: $DISK"

echo "info: loading ZFS kernel module"
modprobe zfs || die "failed to load zfs module"

if zpool list -H zroot >/dev/null 2>&1; then
  echo "warning: zpool zroot is already imported; install will attempt to export/recreate it" >&2
fi

# Generate persistent password hashes and machine-id.
echo "info: generating yescrypt password hash files"
mkdir -p "$PASSWORD_DIR"
make_password_hash jackson "$PASSWORD_DIR/jackson"
make_password_hash root "$PASSWORD_DIR/root"

echo "info: generating persistent machine-id"
mkdir -p "$MACHINE_ID_DIR"
uuidgen -r | tr -d '-' > "$MACHINE_ID_DIR/machine-id"
chmod 444 "$MACHINE_ID_DIR/machine-id"

# Partition/format the disk and install the bootstrap NixOS configuration. This
# prompts for the native ZFS encryption passphrase.
echo "info: running disko-install"
disko-install \
  --write-efi-boot-entries \
  --extra-files "$PASSWORD_DIR" /persist/etc/passwords \
  --extra-files "$MACHINE_ID_DIR/machine-id" /persist/etc/machine-id \
  --flake "${INSTALL_FLAKE}#murph-install" \
  --disk main "$DISK"

# Normalize the target mount at /mnt. disko-install may have used a temporary
# root such as /mnt/disko-install-root.
echo "info: normalizing target mount at ${MOUNTPOINT}"

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
  echo "info: loading ZFS encryption key for zroot/enc"
  zfs load-key zroot/enc
fi

zfs mount zroot/enc/local/root
zfs mount zroot/enc/local/nix
zfs mount zroot/enc/local/docker
zfs mount zroot/enc/safe/persist

mkdir -p "${MOUNTPOINT}/boot"
mount /dev/disk/by-label/ESP "${MOUNTPOINT}/boot"

findmnt -R "$MOUNTPOINT"

# Leave the target mounted so preserved state can be copied into /mnt/persist
# before first boot.
cat <<EOF

Install finished. The target is still mounted at ${MOUNTPOINT}.

Before rebooting, mount your backup USB and restore preserved host keys and
personal state into ${MOUNTPOINT}/persist. Adjust /path/to/backup as needed.

Required/recommended state:

   mkdir -p ${MOUNTPOINT}/persist/etc/ssh
   rsync -a /path/to/backup/murph-ssh-host-keys/ssh_host_* ${MOUNTPOINT}/persist/etc/ssh/
   chmod 600 ${MOUNTPOINT}/persist/etc/ssh/ssh_host_*_key
   chmod 644 ${MOUNTPOINT}/persist/etc/ssh/ssh_host_*_key.pub

   mkdir -p ${MOUNTPOINT}/persist/home/jackson/local/config ${MOUNTPOINT}/persist/home/jackson/local/share
   rsync -a /path/to/backup/jackson/repositories/ ${MOUNTPOINT}/persist/home/jackson/repositories/
   rsync -a /path/to/backup/jackson/.ssh/ ${MOUNTPOINT}/persist/home/jackson/.ssh/
   rsync -a /path/to/backup/jackson/.config/gh/ ${MOUNTPOINT}/persist/home/jackson/local/config/gh/
   rsync -a /path/to/backup/jackson/.local/share/fish/ ${MOUNTPOINT}/persist/home/jackson/local/share/fish/
   rsync -a --exclude 'S.gpg-agent*' /path/to/backup/jackson/.local/share/gnupg/ ${MOUNTPOINT}/persist/home/jackson/local/share/gnupg/
   rsync -a /path/to/backup/jackson/.local/share/keyrings/ ${MOUNTPOINT}/persist/home/jackson/local/share/keyrings/

Optional extra explicitly persisted home state:

   rsync -a /path/to/backup/jackson/scratch/ ${MOUNTPOINT}/persist/home/jackson/scratch/
   rsync -a /path/to/backup/jackson/share/ ${MOUNTPOINT}/persist/home/jackson/share/
   rsync -a /path/to/backup/jackson/.mozilla/firefox/ ${MOUNTPOINT}/persist/home/jackson/.mozilla/firefox/

Fix ownership/permissions, lock down /persist itself after all copying is
finished, then unmount and reboot:

   chown -R 1000:100 ${MOUNTPOINT}/persist/home/jackson
   chmod 700 ${MOUNTPOINT}/persist/home/jackson/.ssh ${MOUNTPOINT}/persist/home/jackson/local/share/fish ${MOUNTPOINT}/persist/home/jackson/local/share/gnupg
   chown root:root ${MOUNTPOINT}/persist
   chmod 700 ${MOUNTPOINT}/persist
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

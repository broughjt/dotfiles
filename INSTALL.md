# Install plan

Boot a NixOS installer USB, connect network, then get this repo onto the installer.

Preflight:

sudo -i
modprobe zfs
lsblk

The NixOS installer runs with a small writable overlay for `/nix`.
`murph-install` is a small bootstrap configuration so the live USB does not
have to realize the full GNOME/Emacs/agent workstation closure before the
target NVMe is mounted. Still check the live store before starting:

df -h /nix /nix/.rw-store /tmp /run/user/0
free -h

If retrying after a failed install attempt filled the live store, collect
garbage before running `disko-install` again:

nix --extra-experimental-features "nix-command flakes" store gc

Create password hash files outside the repository. These are copied into
`/persist` during `disko-install`; do not commit them.

mkdir -p /tmp/murph-passwords
make_password_hash() {
  user=$1
  out=$2

  while true; do
    read -rsp "$user password: " p1; echo
    read -rsp "confirm $user password: " p2; echo
    if [ "$p1" = "$p2" ]; then
      printf '%s\n' "$p1" | nix --extra-experimental-features "nix-command flakes" run nixpkgs#mkpasswd -- -m sha-512 --stdin > "$out"
      unset p1 p2
      break
    fi
    unset p1 p2
    echo "passwords did not match; try again" >&2
  done
}
make_password_hash jackson /tmp/murph-passwords/jackson
make_password_hash root /tmp/murph-passwords/root
chmod 600 /tmp/murph-passwords/*

Create a persistent machine-id outside the repository too.

mkdir -p /tmp/murph-etc
uuidgen -r | tr -d - > /tmp/murph-etc/machine-id
chmod 444 /tmp/murph-etc/machine-id

Then run the destructive install:

nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko/latest#disko-install -- \
  --write-efi-boot-entries \
  --extra-files /tmp/murph-passwords /persist/etc/passwords \
  --extra-files /tmp/murph-etc/machine-id /persist/etc/machine-id \
  --flake /path/to/dotfiles#murph-install \
  --disk main /dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380

This will wipe the NVMe and prompt you for the native ZFS encryption passphrase.

After `disko-install` finishes, normalize the target mount at `/mnt` for the
post-install steps. The installer may have used a temporary root such as
`/mnt/disko-install-root`.

umount -R /mnt/disko-install-root || true
zpool export zroot || true
zpool import -f -N -R /mnt zroot
zfs load-key zroot/enc
zfs mount zroot/enc/local/root
zfs mount zroot/enc/local/nix
zfs mount zroot/enc/local/docker
zfs mount zroot/enc/safe/persist
mount /dev/disk/by-label/ESP /mnt/boot
findmnt -R /mnt

Before reboot, restore preserved SSH host keys if available. If these are
missing, the installed system will generate fresh host keys and old clients
will need their known-hosts entry updated.

mkdir -p /mnt/persist/etc/ssh
cp -a /path/to/murph-ssh-host-keys/ssh_host_* /mnt/persist/etc/ssh/

Cleanly unmount/export before rebooting if possible:

umount -R /mnt
zpool export zroot

Then reboot into the bootstrap system.

After first boot, restore this repository and the personal state needed by the
full configuration:

rsync -a /mnt/murph-home-backup-usb/jackson/repositories/ ~/repositories/
rsync -a /mnt/murph-home-backup-usb/jackson/.ssh/ ~/.ssh/
rsync -a /mnt/murph-home-backup-usb/jackson/.local/share/gnupg/ ~/.local/share/gnupg/
rsync -a /mnt/murph-home-backup-usb/jackson/.config/gh/ ~/.config/gh/

Then switch from the bootstrap profile to the full workstation profile. This
build now uses the NVMe-backed `/nix`, not the live USB overlay:

sudo nixos-rebuild switch --flake ~/repositories/dotfiles#murph

Verify rollback/persistence after the full switch:

findmnt /persist
findmnt /nix
findmnt /var/lib/docker
zfs list
zfs list -t snapshot

Test impermanence:

sudo touch /root/should-disappear
touch ~/scratch/should-persist
touch ~/should-disappear
reboot

Expected:

- `/root/should-disappear` gone
- `~/should-disappear` gone
- `~/scratch/should-persist` still exists

Then selectively restore the rest of home from your backup into the persisted
dirs:

rsync -a /mnt/murph-home-backup-usb/jackson/local/ ~/local/
rsync -a /mnt/murph-home-backup-usb/jackson/scratch/ ~/scratch/
rsync -a /mnt/murph-home-backup-usb/jackson/share/ ~/share/
rsync -a /mnt/murph-home-backup-usb/jackson/.mozilla/firefox/ ~/.mozilla/firefox/

Secure Boot/lanzaboote should be phase 2 after this boots cleanly.

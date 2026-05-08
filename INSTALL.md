# Install plan

Boot a NixOS installer USB, connect network, then get this repo onto the installer.

Preflight:

sudo -i
modprobe zfs
lsblk

Then run the destructive install:

nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko/latest#disko-install -- \
  --write-efi-boot-entries \
  --flake /path/to/dotfiles#murph \
  --disk main /dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380

This will wipe the NVMe and prompt you for the native ZFS encryption passphrase.

Before reboot, restore preserved SSH host keys:

mkdir -p /mnt/persist/etc/ssh
cp -a /path/to/murph-ssh-host-keys/ssh_host_* /mnt/persist/etc/ssh/

Set passwords and persist /etc/shadow:

nixos-enter --root /mnt -c 'passwd jackson'
nixos-enter --root /mnt -c 'passwd root'
install -D -m 0600 /mnt/etc/shadow /mnt/persist/etc/shadow

Then reboot.

After first boot

Verify rollback/persistence:

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

Then selectively restore from your home backup into the persisted dirs:

rsync -a /mnt/murph-home-backup-usb/jackson/repositories/ ~/repositories/
rsync -a /mnt/murph-home-backup-usb/jackson/local/ ~/local/
rsync -a /mnt/murph-home-backup-usb/jackson/scratch/ ~/scratch/
rsync -a /mnt/murph-home-backup-usb/jackson/share/ ~/share/
rsync -a /mnt/murph-home-backup-usb/jackson/.ssh/ ~/.ssh/
rsync -a /mnt/murph-home-backup-usb/jackson/.local/share/gnupg/ ~/.local/share/gnupg/
rsync -a /mnt/murph-home-backup-usb/jackson/.mozilla/firefox/ ~/.mozilla/firefox/
rsync -a /mnt/murph-home-backup-usb/jackson/.config/gh/ ~/.config/gh/

Secure Boot/lanzaboote should be phase 2 after this boots cleanly.

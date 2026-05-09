# Murph install

Boot a NixOS installer USB, connect to the network, then become root:

```sh
sudo -i
```

Run the installer app:

```sh
nix --extra-experimental-features "nix-command flakes" \
  run github:broughjt/dotfiles#installMurph
```

This script will:

- check the target disk and installer resources
- prompt for confirmation before erasing the NVMe
- generate yescrypt password hashes for `jackson` and `root`
- generate a persistent machine-id
- run `disko-install` with `#murph-install`
- prompt for the ZFS encryption passphrase
- remount the target at `/mnt`
- ask whether to unmount/export the target before reboot

Useful overrides:

```sh
nix run github:broughjt/dotfiles#installMurph -- \
  --disk /dev/disk/by-id/...
```

The default target disk is:

```text
/dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380
```

## Preserved keys and personal state

If you have previous SSH host keys, restore them before rebooting into the new
system. Either run the installer with `--keep-mounted` or answer `n` when it
asks whether to unmount the target, then copy the keys:

```sh
mkdir -p /mnt/persist/etc/ssh
cp -a /path/to/murph-ssh-host-keys/ssh_host_* /mnt/persist/etc/ssh/
chmod 600 /mnt/persist/etc/ssh/ssh_host_*_key
chmod 644 /mnt/persist/etc/ssh/ssh_host_*_key.pub
umount -R /mnt
zpool export zroot
```

If you skip this, the installed system will generate fresh host keys and old
clients will need their known-hosts entry updated.

After the first boot, mount your backup USB and restore the personal state
needed for the full configuration:

```sh
rsync -a /mnt/murph-home-backup-usb/jackson/repositories/ ~/repositories/
rsync -a /mnt/murph-home-backup-usb/jackson/.ssh/ ~/.ssh/
rsync -a /mnt/murph-home-backup-usb/jackson/.local/share/gnupg/ ~/.local/share/gnupg/
rsync -a /mnt/murph-home-backup-usb/jackson/.config/gh/ ~/.config/gh/
```

Then switch from the bootstrap profile to the full workstation profile:

```sh
sudo nixos-rebuild switch --flake ~/repositories/dotfiles#murph
```

Verify rollback and persistence:

```sh
findmnt /persist
findmnt /nix
findmnt /var/lib/docker
zfs list
zfs list -t snapshot
```

Optional impermanence test:

```sh
sudo touch /root/should-disappear
touch ~/scratch/should-persist
touch ~/should-disappear
reboot
```

Expected after reboot:

- `/root/should-disappear` is gone
- `~/should-disappear` is gone
- `~/scratch/should-persist` remains

Restore additional persisted home directories as needed:

```sh
rsync -a /mnt/murph-home-backup-usb/jackson/local/ ~/local/
rsync -a /mnt/murph-home-backup-usb/jackson/scratch/ ~/scratch/
rsync -a /mnt/murph-home-backup-usb/jackson/share/ ~/share/
rsync -a /mnt/murph-home-backup-usb/jackson/.mozilla/firefox/ ~/.mozilla/firefox/
```

Secure Boot/lanzaboote is intentionally left for a later phase after the base
install boots cleanly.

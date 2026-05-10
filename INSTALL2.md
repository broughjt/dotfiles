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

The script will:

- check the target disk and installer resources
- erase the configured NVMe
- generate yescrypt password hashes for `jackson` and `root`
- generate a persistent machine-id
- run `disko-install` with `#murph-install`
- prompt for the ZFS encryption passphrase
- remount the target at `/mnt`
- leave the target mounted so preserved keys/state can be restored manually

The target disk is:

```text
/dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380
```

## Restore preserved state before reboot

After the script finishes, the new system is mounted at `/mnt`. Mount your
backup USB and copy preserved state into `/mnt/persist`, not `/mnt/home`.
Adjust `/path/to/backup` as needed.

Restore system SSH host keys:

```sh
mkdir -p /mnt/persist/etc/ssh
rsync -a /path/to/backup/murph-ssh-host-keys/ssh_host_* /mnt/persist/etc/ssh/
chmod 600 /mnt/persist/etc/ssh/ssh_host_*_key
chmod 644 /mnt/persist/etc/ssh/ssh_host_*_key.pub
```

Restore personal state needed for the full configuration:

```sh
mkdir -p /mnt/persist/home/jackson/.local/share /mnt/persist/home/jackson/.config
rsync -a /path/to/backup/jackson/repositories/ /mnt/persist/home/jackson/repositories/
rsync -a /path/to/backup/jackson/.ssh/ /mnt/persist/home/jackson/.ssh/
rsync -a --exclude 'S.gpg-agent*' /path/to/backup/jackson/.local/share/gnupg/ /mnt/persist/home/jackson/.local/share/gnupg/
rsync -a /path/to/backup/jackson/.config/gh/ /mnt/persist/home/jackson/.config/gh/
chown -R 1000:100 /mnt/persist/home/jackson
chmod 700 /mnt/persist/home/jackson/.ssh /mnt/persist/home/jackson/.local/share/gnupg
```

Optionally restore more persisted home directories now too:

```sh
rsync -a /path/to/backup/jackson/local/ /mnt/persist/home/jackson/local/
rsync -a /path/to/backup/jackson/scratch/ /mnt/persist/home/jackson/scratch/
rsync -a /path/to/backup/jackson/share/ /mnt/persist/home/jackson/share/
rsync -a /path/to/backup/jackson/.mozilla/firefox/ /mnt/persist/home/jackson/.mozilla/firefox/
chown -R 1000:100 /mnt/persist/home/jackson
```

After you have finished copying state, it is also safe to lock down the
persistent backing mount itself. The installed NixOS config does this
declaratively on boot too:

```sh
chown root:root /mnt/persist
chmod 700 /mnt/persist
```

Then unmount and reboot:

```sh
umount -R /mnt
zpool export zroot
reboot
```

## First boot

Switch from the bootstrap profile to the full workstation profile:

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

Secure Boot/lanzaboote is intentionally left for a later phase after the base
install boots cleanly.

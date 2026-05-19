# Murph install

## Create a secrets backup

Plug in a USB stick and run `lsblk` to find its mount point. You should see
something like:

```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    1  57.6G  0 disk
└─sda1        8:1    1  57.6G  0 part /run/media/jackson/USB
zram0       253:0    0  15.3G  0 disk [SWAP]
nvme0n1     259:0    0 232.9G  0 disk
├─nvme0n1p1 259:1    0     1G  0 part /boot
└─nvme0n1p2 259:2    0 231.9G  0 part
```

If the USB stick is not already mounted, mount it with:

```
sudo mkdir -p /run/media/jackson/USB
sudo mount /dev/sda1 /run/media/jackson/USB
```

Run the secrets backup script:

```sh
sudo nix run .#backupMurphSecrets -- /run/media/jackson/USB
```

The secrets backup carries identity state needed after reinstall:

- system SSH host keys: `/persist/etc/ssh/ssh_host_{ed25519,rsa}_key{,.pub}`
- personal SSH key: `~/local/secrets/ssh`
- GnuPG secret key material/revocations: `~/local/secrets/gnupg`

Manually back up anything else you'd like to keep using `cp` or `rsync`.

Unmount the USB stick:

```
sudo umount /dev/sda1
```

Then remove the USB.

## Flash the NixOS installer

Plug in a different USB stick and find its device name with `lsblk`. Note, for
writing the ISO, we need the whole device (`/dev/sda`), not a specific partition
on that device (`/dev/sda1`). Flash the NixOS installer with:

```
sudo nix run .#flashNixosInstaller -- /dev/sda
```

## Install

Boot from the USB, connect to a network, and run the installer script

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
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
- leave the target mounted so backup state can be restored manually

The target disk is:

```text
/dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380
```

## Restore secrets before reboot

After the installer finishes, the new system remains mounted at `/mnt`. If you made a secrets backup, mount the backup USB and restore it with the restore script:

```sh
sudo mkdir -p /run/media/jackson/USB
sudo mount /dev/sda1 /run/media/jackson/USB

sudo nix --extra-experimental-features "nix-command flakes" \
  run github:broughjt/dotfiles#restoreMurphSecrets -- \
  /run/media/jackson/USB/murph-secrets-*.tar.gz.age \
  /mnt
```

The archive contains paths relative to `/persist` and is extracted into
`/mnt/persist`. The restore app fixes the expected ownership and permissions
after extraction. Copy any other state you want to keep manually.

Then unmount and reboot:

```sh
sudo umount -R /mnt
sudo zpool export zroot
sudo reboot
```

## First boot

Switch from the bootstrap profile to the full profile:

```sh
sudo nixos-rebuild switch --flake github:broughjt/dotfiles#murph
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

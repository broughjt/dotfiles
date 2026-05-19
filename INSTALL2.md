# Murph install

## Before reinstall: create a secrets archive

If the old system is still bootable, create a small encrypted secrets archive on
a mounted USB drive. It is encrypted with `age --passphrase`.

```sh
# Replace /run/media/jackson/USB with the mounted USB path.
sudo nix run .#backupMurphSecrets -- /run/media/jackson/USB
```

The secrets archive carries only identity/security state needed after reinstall:

- system SSH host keys: `/persist/etc/ssh/ssh_host_{ed25519,rsa}_key{,.pub}`
- personal SSH key material: `~/local/secrets/ssh`
- GnuPG secret key material/revocations: `~/local/secrets/gnupg`

Back up anything else manually if you decide you want it, preferably by copying
specific paths rather than broad state directories.

## Install

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
- optionally restore the murph secrets archive from USB
- leave the target mounted so additional state can be restored manually

The target disk is:

```text
/dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380
```

## Restore secrets before reboot

After the installer finishes, the new system is mounted at `/mnt`. If you made a
secrets archive, mount the backup USB and restore it with the restore app:

```sh
nix --extra-experimental-features "nix-command flakes" \
  run github:broughjt/dotfiles#restoreMurphSecrets -- \
  /path/to/murph-secrets-*.tar.gz.age \
  /mnt
```

If the installer USB and backup USB cannot be plugged in at the same time, let
the installer finish, swap USB drives, mount the backup USB, and run the restore
app while the target remains mounted.

The archive contains paths relative to `/persist` and is extracted into
`/mnt/persist`. The restore app fixes the expected ownership and permissions
after extraction. Copy any other state you want to keep manually.

After you have finished copying state, lock down the persistent backing mount.
The installed NixOS config does this declaratively on boot too:

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

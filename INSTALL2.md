# Murph install

## Before reinstall: create state archives

If the old system is still bootable, create explicit state archives on a mounted
USB drive. The secrets archive is encrypted with `age --passphrase`; the
convenience archive is unencrypted and optional.

```sh
# Replace /run/media/jackson/USB with the mounted USB path.
sudo nix run .#backupMurphSecrets -- /run/media/jackson/USB
sudo nix run .#backupMurphConvenience -- /run/media/jackson/USB
```

The secrets archive carries identity/security state needed after reinstall:

- system SSH host keys: `/persist/etc/ssh`
- personal SSH private key: `~/local/secrets/ssh`
- GnuPG keys/keyrings/trust state: `~/local/share/gnupg` (runtime files and store-backed config excluded)
- GNOME/libsecret keyrings: `~/local/share/keyrings`

The convenience archive carries useful but nonessential state:

- `~/repositories`
- `~/share`
- `~/scratch`
- Firefox profile: `~/.mozilla/firefox`
- SSH `known_hosts`: `~/local/hacks/ssh/known_hosts/known_hosts`
- fish history: `~/local/hacks/fish/fish_history/fish_history`
- tmux-resurrect state: `~/local/hacks/tmux/resurrect/resurrect`
- direnv trust decisions: `~/local/share/direnv/{allow,deny}`

The convenience archive is intentionally unencrypted for ease of use, but it may
still contain private browsing, shell, project, and personal-file state.

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
- optionally restore murph state archives from USB
- leave the target mounted so additional state can be restored manually

The target disk is:

```text
/dev/disk/by-id/nvme-WD_BLACK_SN770_250GB_23013S803380
```

## Restore preserved state before reboot

After the installer finishes, the new system is mounted at `/mnt`. If you made
state archives, mount the backup USB and restore them with the restore apps:

```sh
nix --extra-experimental-features "nix-command flakes" \
  run github:broughjt/dotfiles#restoreMurphSecrets -- \
  /path/to/murph-secrets-*.tar.gz.age /mnt

nix --extra-experimental-features "nix-command flakes" \
  run github:broughjt/dotfiles#restoreMurphConvenience -- \
  /path/to/murph-convenience-*.tar.gz /mnt
```

The convenience archive is optional. If the installer USB and backup USB cannot
be plugged in at the same time, let the installer finish, swap USB drives, mount
the backup USB, and run the restore apps while the target remains mounted.

The archives contain paths relative to `/persist` and are extracted into
`/mnt/persist`. The restore apps fix the expected ownership and permissions
after extraction.

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

# Install kipp, a headless ThinkCentre, from the kipp-installer stick.
#
# Run on murph, on the same LAN as the installer. Erases the drive named in
# nix/modules/hosts/kipp/disko.nix.
#
# What the machine cannot take from the repository is provisioned here: the
# console password from the password store, and the tailnet auth key from a
# prompt. Both go under /persist, because kipp's root is rolled back on every
# boot and anything staged elsewhere would be gone before it was read.

set -euo pipefail

flake=${KIPP_FLAKE:-@DOTFILES_FLAKE@}
name=kipp
console_entry=${KIPP_CONSOLE_PASSWORD:-$name/console-password}

usage() {
  cat <<'USAGE'
Usage:
  install-kipp [installer]

Erases the drive kipp's disko configuration names, then installs
nixosConfigurations.kipp. The installer defaults to root@kipp-installer.local.

Environment:
  KIPP_FLAKE             the flake to install from (default: the one this app
                         was built from)
  KIPP_CONSOLE_PASSWORD  default kipp/console-password (generated if absent)
  KIPP_SSH_PORT          default 22; for rehearsing against a QEMU port forward
USAGE
}

case ${1-} in
  -h | --help)
    usage
    exit 1
    ;;
esac
[ $# -le 1 ] || {
  usage >&2
  exit 1
}
target=${1:-root@kipp-installer.local}

# The installer generates new host keys whenever it is reflashed, so do not
# record them.
ssh_port=${KIPP_SSH_PORT:-22}
ssh_opts=(-p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
export NIX_SSHOPTS="${ssh_opts[*]}"

step() { printf '\n==> %s\n' "$*"; }

config="$flake#nixosConfigurations.$name.config"

step "Evaluating $name's drives"
mapfile -t disks < <(nix eval --raw "$config.disko.devices.disk" \
  --apply 'disks: builtins.concatStringsSep "\n" (map (disk: disk.device) (builtins.attrValues disks))')

step "Checking the installer is reachable and sees every drive"
ssh "${ssh_opts[@]}" "$target" bash -s -- "${disks[@]}" <<'REMOTE'
hostname
grep -q 'VARIANT_ID="\?installer' /etc/os-release || {
  echo "this is not an installer; refusing to erase a running system" >&2
  exit 1
}
missing=0
for disk in "$@"; do
  if [ -e "$disk" ]; then
    echo "found $disk -> $(readlink -f "$disk")"
  else
    echo "MISSING $disk" >&2
    missing=1
  fi
done
exit $missing
REMOTE

# Generated rather than required: nobody logs in with it unless they have
# carried a display and a keyboard to the machine, and there is no reason for a
# human to choose it.
if ! pass show "$console_entry" >/dev/null 2>&1; then
  step "Generating a console password ($console_entry)"
  pass generate -n "$console_entry" 24 >/dev/null
fi

# Asked for rather than kept in the password store: joining the tailnet uses the
# key up, so a stored one would pass any check here and fail on first boot.
# Asked before the slow steps, not after.
step "Tailscale auth key"
echo "Create a key that is not reusable, not ephemeral and untagged at" >&2
echo "    https://login.tailscale.com/admin/settings/keys" >&2
if ! read -rs -p "Auth key: " authkey; then
  echo >&2
  echo "install-kipp: no auth key given." >&2
  exit 1
fi
echo >&2
case $authkey in
  tskey-auth-*) ;;
  *)
    echo "install-kipp: that does not look like an auth key (tskey-auth-...)." >&2
    exit 1
    ;;
esac

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
umask 077

step "Staging secrets"
# install -d gives parents the leaf's mode, and tar would carry a 0700 /persist
# or /persist/etc onto the new system before its own activation sets them.
install -d -m 0755 "$staging/persist" "$staging/persist/etc"
install -d -m 0700 "$staging/persist/etc/passwords"
install -m 0600 /dev/null "$staging/persist/etc/tailscale-authkey"
printf '%s\n' "$authkey" > "$staging/persist/etc/tailscale-authkey"
# hashedPasswordFile wants the hash, and root reads it during activation, so it
# is root-only. Never stage the plaintext; the password store keeps that.
install -m 0600 /dev/null "$staging/persist/etc/passwords/console"
pass show "$console_entry" | head -n 1 | mkpasswd -m yescrypt -s \
  > "$staging/persist/etc/passwords/console"

cat <<EOF

About to erase, on $target:
$(printf '    %s\n' "${disks[@]}")

EOF
read -r -p "Type 'erase' to continue: " confirm
[ "$confirm" = erase ] || {
  echo "install-kipp: aborted." >&2
  exit 1
}

# murph builds: both machines are x86_64, so copying the closure beats building
# on the target, as on `case`. The installer identifies itself as one, so
# nixos-anywhere installs from it rather than kexec'ing away from it.
step "Partitioning and installing (destructive)"
nixos_anywhere() {
  nixos-anywhere --flake "$flake#$name" --target-host "$target" --ssh-port "$ssh_port" "$@"
}
nixos_anywhere --phases disko,install --extra-files "$staging"

# kipp's firmware tries USB before its own drive, so that a reinstall never
# needs a display to pick the stick. The price is that the reboot below would
# come straight back to the installer. BootNext overrides the order for one
# boot, which is enough: the stick can be pulled whenever someone is next
# downstairs. If the firmware ignores it, nothing is lost; pull the stick and
# power-cycle.
step "Pointing the next boot at the installed system"
ssh "${ssh_opts[@]}" "$target" bash -s <<'REMOTE' || echo "install-kipp: could not set BootNext; pull the stick before kipp will boot." >&2
set -euo pipefail
entry=$(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\? *Linux Boot Manager.*/\1/p' | head -n 1)
[ -n "$entry" ] || { echo "no 'Linux Boot Manager' entry found" >&2; exit 1; }
efibootmgr --bootnext "$entry" | grep -i '^BootNext'
REMOTE

# Unmounts and exports zroot, which matters: forceImportRoot is off, and a pool
# last imported under the installer's host id would be refused.
step "Rebooting"
nixos_anywhere --phases reboot

step "Done. $name should join the tailnet within a couple of minutes. Pull the installer stick when convenient."

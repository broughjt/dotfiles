# Install a `tars` Raspberry Pi 5 from the tars-installer image.
# See documentation/tars-install.md.
#
# Run on murph. Erases both drives named in the instance's nix/hosts/<name>.nix.
#
# One nixosConfigurations entry per machine, because a Pi cannot derive its
# drives the way a Hetzner VM derives its hostname from cloud-init. Everything
# else that differs between machines is provisioned here rather than committed:
# the console password comes from the password store, under a prefix named after
# the instance, the Wi-Fi passphrases and disk encryption keys from entries
# specified on the command line, and the tailnet auth key from a prompt.

set -euo pipefail

flake=${TARS_FLAKE:-@DOTFILES_FLAKE@}

usage() {
  cat <<'USAGE'
Usage:
  install-tars <name> <installer> --network SSID=ENTRY [--network SSID=ENTRY]...
    [--disk-key PATH=ENTRY]...

Erases every drive the instance's disko configuration names, then installs the
nixosConfigurations.<name> built by nix/hosts/<name>.nix.

Each --network is a Wi-Fi network the installed system joins, whose passphrase
is the first line of a password store entry. Each --disk-key is a disk
encryption key, the first line of a password store entry, put at PATH on the
installer before the drives are formatted. Every file:// keylocation in the
disko configuration needs one:

  install-tars tars1 tars-installer.local --network TheShire=wifi/theshire \
    --disk-key /tmp/easystore.key=tars1/easystore-key

Environment:
  TARS_FLAKE               the flake to install from (default: the one this app
                           was built from)
  TARS_CONSOLE_PASSWORD    default <name>/console-password (generated if absent)
USAGE
}

if [ $# -lt 2 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  usage
  exit 1
fi

name=$1
target="root@$2"
shift 2

networks=()
disk_keys=()
while [ $# -gt 0 ]; do
  case $1 in
    --disk-key)
      if [ $# -lt 2 ]; then
        echo "install-tars: --disk-key needs a PATH=ENTRY argument." >&2
        exit 1
      fi
      key_path=${2%%=*}
      if [ "${key_path#/}" = "$key_path" ] || [ "$key_path" = "$2" ] || [ -z "${2#*=}" ]; then
        echo "install-tars: --disk-key wants /PATH=ENTRY, got '$2'." >&2
        exit 1
      fi
      disk_keys+=("$2")
      shift 2
      ;;
    --network)
      if [ $# -lt 2 ]; then
        echo "install-tars: --network needs an SSID=ENTRY argument." >&2
        exit 1
      fi
      # Checked here rather than where the file is written, so a typo costs
      # nothing instead of surfacing after several minutes of evaluation.
      ssid=${2%%=*}
      if [ -z "$ssid" ] || [ "$ssid" = "$2" ] || [ -z "${2#*=}" ]; then
        echo "install-tars: --network wants SSID=ENTRY, got '$2'." >&2
        exit 1
      fi
      networks+=("$2")
      shift 2
      ;;
    *)
      echo "install-tars: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# A cable would still get it onto the tailnet, but an install without Wi-Fi is
# almost certainly a forgotten flag.
if [ ${#networks[@]} -eq 0 ]; then
  echo "install-tars: give at least one --network SSID=ENTRY." >&2
  exit 1
fi

console_entry=${TARS_CONSOLE_PASSWORD:-$name/console-password}

# The installer generates new host keys on every boot, so do not record them.
ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
export NIX_SSHOPTS="${ssh_opts[*]}"

step() { printf '\n==> %s\n' "$*"; }

nixos_anywhere() {
  nixos-anywhere \
    --flake "$flake#$name" \
    --target-host "$target" \
    --build-on remote \
    "$@"
}

# Only stdout is discarded, so the secret stays off the terminal while gpg's own
# diagnostics reach stderr. A failure here is as often a gpg problem as a
# missing entry, and the two need different fixes.
require_entry() {
  if ! pass show "$1" >/dev/null; then
    echo >&2
    echo "install-tars: could not read '$1' from the password store." >&2
    echo "$2" >&2
    echo "If gpg reported a key error above, check that 'command -v gpg' is your" >&2
    echo "wrapped gpg rather than an unwrapped one earlier on PATH." >&2
    exit 1
  fi
}

config="$flake#nixosConfigurations.$name.config"

step "Evaluating $name's drives"
mapfile -t disks < <(nix eval --raw "$config.disko.devices.disk" \
  --apply 'disks: builtins.concatStringsSep "\n" (map (disk: disk.device) (builtins.attrValues disks))')

# The key files disko will read while it creates encrypted datasets. Matching
# them against --disk-key here means a forgotten flag stops the install before
# anything is erased, rather than at zfs create with the partition tables gone.
mapfile -t key_files < <(nix eval --raw "$config.disko.devices.zpool" --apply '
  pools:
  let
    locations = builtins.concatMap (
      pool:
      [ (pool.rootFsOptions.keylocation or "") ]
      ++ map (dataset: dataset.options.keylocation or "") (builtins.attrValues pool.datasets)
    ) (builtins.attrValues pools);
    files = builtins.filter (location: builtins.match "file://.*" location != null) locations;
  in
  builtins.concatStringsSep "\n" (map (builtins.substring 7 (-1)) files)')

for key_file in "${key_files[@]}"; do
  found=0
  for disk_key in "${disk_keys[@]}"; do
    [ "${disk_key%%=*}" = "$key_file" ] && found=1
  done
  if [ $found -eq 0 ]; then
    echo "install-tars: $name's disks read an encryption key from $key_file." >&2
    echo "Give --disk-key $key_file=ENTRY, naming its password store entry." >&2
    exit 1
  fi
done
for disk_key in "${disk_keys[@]}"; do
  found=0
  for key_file in "${key_files[@]}"; do
    [ "${disk_key%%=*}" = "$key_file" ] && found=1
  done
  if [ $found -eq 0 ]; then
    echo "install-tars: nothing in $name's disko configuration reads ${disk_key%%=*}." >&2
    exit 1
  fi
done

step "Checking the password store"
for disk_key in "${disk_keys[@]}"; do
  require_entry "${disk_key#*=}" \
    "Its first line should be the encryption key read from ${disk_key%%=*}.
Losing it loses the data, so it is created once and kept:
    openssl rand -hex 32 | pass insert -m ${disk_key#*=}"
done
for network in "${networks[@]}"; do
  require_entry "${network#*=}" \
    "Its first line should be the passphrase for '${network%%=*}'."
done

# Generated rather than required: it exists so that a tars which has lost the
# tailnet can still be logged into over the serial console, and there is no
# reason for a human to choose it.
if ! pass show "$console_entry" >/dev/null 2>&1; then
  step "Generating a console password ($console_entry)"
  pass generate -n "$console_entry" 24 >/dev/null
fi

# Asked for rather than kept in the password store: joining the tailnet uses the
# key up, so a stored one would pass any check here and fail on first boot, when
# the machine has no other way in. Asked before the slow steps, not after.
step "Tailscale auth key"
echo "Create a key that is not reusable, not ephemeral and untagged at" >&2
echo "    https://login.tailscale.com/admin/settings/keys" >&2
if ! read -rs -p "Auth key: " authkey; then
  echo >&2
  echo "install-tars: no auth key given." >&2
  exit 1
fi
echo >&2
case $authkey in
  tskey-auth-*) ;;
  *)
    echo "install-tars: that does not look like an auth key (tskey-auth-...)." >&2
    exit 1
    ;;
esac

step "Evaluating $name's system on murph"
toplevel=$(nix eval --raw "$config.system.build.toplevel.drvPath")
disko=$(nix eval --raw "$config.system.build.diskoScript.drvPath")

step "Checking the installer is reachable and sees every drive"
ssh "${ssh_opts[@]}" "$target" bash -s -- "${disks[@]}" <<'REMOTE'
hostname
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

# murph registered some source paths (e.g. an `inputrc`) without a content
# address or signature, and nix build --store ssh-ng:// uploads inputs without
# --no-check-sigs, so the remote store rejects them. Copying the derivation
# closures first, as a trusted user with --no-check-sigs, means nix build finds
# them already present and uploads nothing.
step "Pre-copying the disko script's derivations to the installer store"
nix copy --derivation --no-check-sigs --to "ssh-ng://$target" "$disko"

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
umask 077

step "Staging secrets from the password store"
install -d -m 0755 "$staging/extra/var/lib"
# nixos-anywhere copies each key to its path on the installer before disko
# runs. Putting it where the installed system reads it is the configuration's
# job, since only it knows that path; see the mount hook in easystore.nix.
disko_args=()
install -d -m 0700 "$staging/disk-keys"
for index in "${!disk_keys[@]}"; do
  disk_key=${disk_keys[$index]}
  pass show "${disk_key#*=}" | head -n 1 | tr -d '\n' > "$staging/disk-keys/$index"
  disko_args+=(--disk-encryption-keys "${disk_key%%=*}" "$staging/disk-keys/$index")
done
install -m 0600 /dev/null "$staging/extra/var/lib/tailscale-authkey"
printf '%s\n' "$authkey" > "$staging/extra/var/lib/tailscale-authkey"
# hashedPasswordFile wants the hash, and root reads it during activation, so it
# is root-only. Never stage the plaintext; the password store keeps that.
install -m 0600 /dev/null "$staging/extra/var/lib/console-password"
pass show "$console_entry" | head -n 1 | mkpasswd -m yescrypt -s \
  > "$staging/extra/var/lib/console-password"

# NetworkManager ignores profiles that are not root-only, and nixos-anywhere
# extracts extra files as root, keeping their modes. The passphrase reaches
# nmcli as an argument, briefly visible to other users on murph; nmcli --offline
# has no other way to take it.
connections="$staging/extra/etc/NetworkManager/system-connections"
# install -d gives parents the leaf's mode, and tar would carry a 0700 /etc onto
# the new root.
install -d -m 0755 "$staging/extra/etc/NetworkManager"
install -d -m 0700 "$connections"
for network in "${networks[@]}"; do
  ssid=${network%%=*}
  entry=${network#*=}
  step "Adding the Wi-Fi network '$ssid' from $entry"
  # NetworkManager reads any *.nmconnection file; the name is only for people.
  file="$connections/$(printf '%s' "$ssid" | tr -c 'A-Za-z0-9._-' '_').nmconnection"
  install -m 0600 /dev/null "$file"
  nmcli --offline connection add type wifi con-name "$ssid" ssid "$ssid" \
    wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$(pass show "$entry" | head -n 1)" \
    > "$file"
done

step "Partitioning and formatting every drive (destructive)"
nixos_anywhere --phases disko "${disko_args[@]}"

step "Pre-copying the system's derivations into the new root's store"
nix copy --derivation --no-check-sigs \
  --to "ssh-ng://$target?remote-store=local%3Froot=%2Fmnt" "$toplevel"

step "Building and installing the system"
nixos_anywhere --phases install,reboot --extra-files "$staging/extra"

step "Done. Pull the installer stick; $name should join the tailnet on first boot."

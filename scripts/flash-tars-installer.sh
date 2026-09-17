# Build the tars-installer image on an aarch64 builder and flash it to a USB
# stick. See documentation/tars-install.md.
#
# The builder is any aarch64 machine with Nix that trusts you over SSH: the
# Raspberry Pi OS stick from flash-tars-bootstrap when no tars exists yet, and a
# running tars afterwards. murph only evaluates and flashes; emulating aarch64
# here takes hours.
#
# Wi-Fi profiles for the networks named on the command line are written into
# the image's root partition before it is flashed, so the installer joins Wi-Fi
# on boot and is reachable as root@tars-installer.local without a serial
# console. They live on the stick, not in the image derivation or the repository.
#
# Run as yourself, not under sudo. Only the write to the stick asks for sudo.

set -euo pipefail

flake=${TARS_FLAKE:-@DOTFILES_FLAKE@}

usage() {
  cat <<'USAGE'
Usage:
  flash-tars-installer <disk> --builder <ssh-destination> \
    --network SSID=ENTRY [--network SSID=ENTRY]...

Builds nixosConfigurations.tars-installer on the builder, copies the image back,
adds the Wi-Fi networks to it, and erases <disk>, a whole USB stick, to write it.
Each --network is a Wi-Fi network the installer joins on boot, whose passphrase
is the first line of a password store entry:

  flash-tars-installer /dev/disk/by-id/usb-... --builder jackson@tars-bootstrap.local \
    --network TheShire=wifi/theshire
  flash-tars-installer /dev/disk/by-id/usb-... --builder jackson@tars1 \
    --network TheShire=wifi/theshire

A build that is already done is not repeated, so reflashing costs only the copy.
If the connection drops mid-build, run it again; finished steps are kept.

Environment:
  TARS_FLAKE  the flake to build from (default: the one this app was built from)
USAGE
}

die() {
  echo "flash-tars-installer: $*" >&2
  exit 1
}

if [ $# -lt 1 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  usage
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  die "run as yourself; the write to the stick uses sudo on its own"
fi

target=$1
shift

builder=
networks=()
while [ $# -gt 0 ]; do
  case $1 in
    --builder)
      [ $# -ge 2 ] && [ -n "$2" ] || die "--builder wants an SSH destination"
      builder=$2
      shift 2
      ;;
    --network)
      if [ $# -lt 2 ] || [ "${2%%=*}" = "$2" ] || [ -z "${2%%=*}" ] || [ -z "${2#*=}" ]; then
        die "--network wants SSID=ENTRY"
      fi
      networks+=("$2")
      shift 2
      ;;
    *)
      usage >&2
      die "unknown argument '$1'"
      ;;
  esac
done

[ -n "$builder" ] || die "give --builder"
# A cable would do instead, but an installer without Wi-Fi is almost certainly
# a forgotten flag.
[ ${#networks[@]} -gt 0 ] || die "give at least one --network"

step() { printf '\n==> %s\n' "$*"; }

# Checked before anything slow, so a wrong path costs nothing.
[ -e "$target" ] || die "target does not exist: $target"
disk=$(readlink -f -- "$target")
[ -b "$disk" ] || die "target is not a block device: $target"
type=$(lsblk --noheadings --nodeps --output TYPE -- "$disk" | tr -d '[:space:]')
[ "$type" = disk ] || die "$target is a $type, not a whole disk"
transport=$(lsblk --noheadings --nodeps --output TRAN -- "$disk" | tr -d '[:space:]')
[ "$transport" = usb ] || die "$target is not a USB disk (TRAN=$transport)"

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
umask 077

# Read before anything slow, so a missing entry costs nothing. NetworkManager
# ignores profiles that are not root-only; debugfs writes them as root with the
# staged mode. The passphrase reaches nmcli as an argument, briefly visible to
# other users on murph; nmcli --offline has no other way to take it.
step "Writing Wi-Fi profiles from the password store"
install -d -m 0700 "$staging/connections"
for network in "${networks[@]}"; do
  ssid=${network%%=*}
  entry=${network#*=}
  # NetworkManager reads any *.nmconnection file; the name is only for people.
  file="$staging/connections/$(printf '%s' "$ssid" | tr -c 'A-Za-z0-9._-' '_').nmconnection"
  install -m 0600 /dev/null "$file"
  nmcli --offline connection add type wifi con-name "$ssid" ssid "$ssid" \
    wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$(pass show "$entry" | head -n 1)" \
    > "$file"
done

store="ssh-ng://$builder"

step "Checking that $builder can build for you"
if ! info=$(nix store info --store "$store" 2>&1); then
  echo "$info" >&2
  die "cannot reach Nix on $builder; check 'ssh $builder nix --version' first"
fi
if ! grep -q '^Trusted: 1' <<<"$info"; then
  die "$builder does not trust your user; add it to trusted-users there"
fi

step "Evaluating tars-installer"
drv=$(nix eval --raw "$flake#nixosConfigurations.tars-installer.config.system.build.sdImage.drvPath")

# murph registered some source paths without a content address or signature,
# and a remote store rejects those when a build uploads them as inputs. Copying
# the derivation closure first, with --no-check-sigs, leaves nothing to upload.
step "Copying the derivations to $builder"
nix copy --derivation --no-check-sigs --to "$store" "$drv"

step "Building on $builder"
# The root keeps the image from being garbage-collected on the builder, which
# is what makes a reflash skip the build.
out=$(ssh "$builder" nix-store --realise "$drv" --add-root tars-installer)
image_zst=$(ssh "$builder" ls "$out"/sd-image/*.img.zst)

step "Copying $(basename "$image_zst") from $builder"
scp "$builder:$image_zst" "$staging/"
image="$staging/$(basename "$image_zst" .zst)"
zstd --decompress --rm "$staging/$(basename "$image_zst")" -o "$image"

# The image has no /etc until the first activation creates it, which leaves a
# directory that is already there alone, as does the tmpfiles rule that owns
# system-connections. debugfs edits the ext4 partition in place without a
# mount, so no sudo is needed and the files come out root-owned.
step "Adding the Wi-Fi profiles to the image"
root_offset=$(sfdisk -J "$image" | jq '
  .partitiontable as $table
  | [$table.partitions[] | select(.type == "83")]
  | if length == 1 then .[0].start * ($table.sectorsize // 512)
    else error("expected one Linux partition, found \(length)") end')
root="$image?offset=$root_offset"
connections=etc/NetworkManager/system-connections
debugfs -w -f - "$root" >/dev/null 2>&1 <<CMDS
mkdir etc
mkdir etc/NetworkManager
mkdir $connections
CMDS
# debugfs exits 0 whatever happens, so every write is read back.
for file in "$staging/connections"/*.nmconnection; do
  name=$(basename "$file")
  debugfs -w -R "write $file $connections/$name" "$root" >/dev/null 2>&1
  debugfs -R "cat $connections/$name" "$root" 2>/dev/null | cmp -s - "$file" \
    || die "could not write $name into the image"
done
debugfs -R "ls -l $connections" "$root" 2>/dev/null

cat <<EOF

About to erase $disk and write the tars installer to it.

EOF
lsblk --output NAME,PATH,SIZE,TYPE,TRAN,MODEL,MOUNTPOINTS -- "$disk"
echo
read -r -p "Type the device path ($disk) to continue: " confirm
[ "$confirm" = "$disk" ] || die "confirmation did not match; aborted"

# sudo resets PATH, so hand it this script's, which has the runtime inputs.
step "Writing $disk"
sudo env "PATH=$PATH" "$BASH" -euo pipefail -s -- "$disk" "$image" <<'ROOT'
disk=$1
image=$2
lsblk --list --noheadings --output PATH -- "$disk" | while read -r device; do
  umount "$device" 2>/dev/null || true
done
dd if="$image" of="$disk" bs=4M conv=fsync status=progress
cmp -n "$(stat -c %s "$image")" "$image" "$disk"
eject "$disk" 2>/dev/null || echo "Could not eject $disk; remove it once activity stops." >&2
ROOT

step "Done. Boot the Pi from $target with the SD card out; it joins Wi-Fi as root@tars-installer.local."

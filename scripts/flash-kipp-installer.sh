# Build the kipp-installer image and flash it to a USB stick. See
# nix/hosts/kipp-installer.nix for what the image is and why it is not the
# stock ISO.
#
# Wi-Fi profiles for the networks named on the command line are written into
# the image's root partition before it is flashed, so the installer joins Wi-Fi
# on boot and is reachable as root@kipp-installer.local with no display. They
# live on the stick, not in the image derivation or the repository.
#
# Run as yourself, not under sudo. Only the write to the stick asks for sudo.

set -euo pipefail

flake=${KIPP_FLAKE:-@DOTFILES_FLAKE@}

usage() {
  cat <<'USAGE'
Usage:
  flash-kipp-installer <disk> --network SSID=ENTRY [--network SSID=ENTRY]...
  flash-kipp-installer <disk> --no-wifi
  flash-kipp-installer --to-file <path> ...

Builds nixosConfigurations.kipp-installer, adds the Wi-Fi networks to the image,
and erases <disk>, a whole USB stick, to write it. Each --network is a Wi-Fi
network the installer joins on boot, whose passphrase is the first line of a
password store entry:

  flash-kipp-installer /dev/disk/by-id/usb-... \
    --network TheShire=wifi/theshire --network CircleMR1=wifi/circlemr1

--no-wifi is for a machine on a cable, which needs nothing: the installer takes
DHCP on any wired interface.

--to-file writes the finished image to <path> instead of a stick, for booting
in QEMU. It needs no sudo and erases nothing.

Environment:
  KIPP_FLAKE  the flake to build from (default: the one this app was built from)
USAGE
}

die() {
  echo "flash-kipp-installer: $*" >&2
  exit 1
}

if [ $# -lt 1 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  usage
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  die "run as yourself; the write to the stick uses sudo on its own"
fi

target=
to_file=
no_wifi=
networks=()
while [ $# -gt 0 ]; do
  case $1 in
    --network)
      if [ $# -lt 2 ] || [ "${2%%=*}" = "$2" ] || [ -z "${2%%=*}" ] || [ -z "${2#*=}" ]; then
        die "--network wants SSID=ENTRY"
      fi
      networks+=("$2")
      shift 2
      ;;
    --no-wifi)
      no_wifi=1
      shift
      ;;
    --to-file)
      [ $# -ge 2 ] && [ -n "$2" ] || die "--to-file wants a path"
      to_file=$2
      shift 2
      ;;
    -*)
      usage >&2
      die "unknown argument '$1'"
      ;;
    *)
      [ -z "$target" ] || die "more than one disk given: '$target' and '$1'"
      target=$1
      shift
      ;;
  esac
done

if [ -n "$to_file" ]; then
  [ -z "$target" ] || die "give a disk or --to-file, not both"
  [ ! -e "$to_file" ] || die "$to_file exists; remove it first"
else
  [ -n "$target" ] || die "give a disk, or --to-file"
fi
# An installer without Wi-Fi is almost certainly a forgotten flag, so leaving it
# out has to be said.
if [ -n "$no_wifi" ]; then
  [ ${#networks[@]} -eq 0 ] || die "--no-wifi and --network contradict each other"
else
  [ ${#networks[@]} -gt 0 ] || die "give at least one --network, or --no-wifi"
fi

step() { printf '\n==> %s\n' "$*"; }

# Checked before anything slow, so a wrong path costs nothing.
if [ -n "$target" ]; then
  [ -e "$target" ] || die "target does not exist: $target"
  disk=$(readlink -f -- "$target")
  [ -b "$disk" ] || die "target is not a block device: $target"
  type=$(lsblk --noheadings --nodeps --output TYPE -- "$disk" | tr -d '[:space:]')
  [ "$type" = disk ] || die "$target is a $type, not a whole disk"
  transport=$(lsblk --noheadings --nodeps --output TRAN -- "$disk" | tr -d '[:space:]')
  [ "$transport" = usb ] || die "$target is not a USB disk (TRAN=$transport)"
fi

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
umask 077

# Read before anything slow, so a missing entry costs nothing. NetworkManager
# ignores profiles that are not root-only; debugfs writes them as root with the
# staged mode. The passphrase reaches nmcli as an argument, briefly visible to
# other users on murph; nmcli --offline has no other way to take it.
install -d -m 0700 "$staging/connections"
if [ ${#networks[@]} -gt 0 ]; then
  step "Writing Wi-Fi profiles from the password store"
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
fi

step "Building kipp-installer"
out=$(nix build --no-link --print-out-paths \
  "$flake#nixosConfigurations.kipp-installer.config.system.build.image")
image=$staging/kipp-installer.img
# The store's copy is read-only and shared; the profiles go into this one.
cp --sparse=always "$out/kipp-installer.img" "$image"
chmod u+w "$image"

if [ ${#networks[@]} -gt 0 ]; then
  # The image has no /etc until the first activation creates it, which leaves a
  # directory that is already there alone, as does the tmpfiles rule that owns
  # system-connections. debugfs edits the ext4 partition in place without a
  # mount, so no sudo is needed and the files come out root-owned.
  step "Adding the Wi-Fi profiles to the image"
  root_offset=$(sfdisk -J "$image" | jq '
    .partitiontable as $table
    | [$table.partitions[] | select(.type == "0FC63DAF-8483-4772-8E79-3D69D8477DE4")]
    | if length == 1 then .[0].start * ($table.sectorsize // 512)
      else error("expected one Linux filesystem partition, found \(length)") end')
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
fi

if [ -n "$to_file" ]; then
  step "Writing $to_file"
  cp --sparse=always "$image" "$to_file"
  step "Done."
  exit 0
fi

cat <<EOF

About to erase $disk and write the kipp installer to it.

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

step "Done. Boot kipp from $target; it should answer as root@kipp-installer.local."

# Flash Raspberry Pi OS Lite to a USB stick, set up to boot as an aarch64 Nix
# builder for the tars installer. See documentation/tars-install.md.
#
# Only needed when no aarch64 NixOS machine exists to build the tars-installer
# image on. Raspberry Pi OS configures its first boot with cloud-init from files
# on the boot partition, so everything the bootstrap needs is written there: a
# user with murph's SSH key and a console password, Wi-Fi, and a first-boot
# command that installs Nix with the same binary caches as the tars
# configurations.
#
# Run as yourself, not under sudo: the password store and the flake evaluation
# need your user. Only the write to the stick asks for sudo.

set -euo pipefail

flake=${TARS_FLAKE:-@DOTFILES_FLAKE@}
image_url=${TARS_BOOTSTRAP_IMAGE_URL:-https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-09-15/2026-09-15-raspios-trixie-arm64-lite.img.xz}
country=${TARS_BOOTSTRAP_COUNTRY:-US}
console_entry=${TARS_BOOTSTRAP_CONSOLE_PASSWORD:-tars-bootstrap/console-password}
hostname=tars-bootstrap
nix_version=2.35.2

usage() {
  cat <<'USAGE'
Usage:
  flash-tars-bootstrap <disk> --network SSID=ENTRY [--network SSID=ENTRY]...

Erases <disk>, a whole USB stick, and writes Raspberry Pi OS Lite to it. Each
--network is a Wi-Fi network whose passphrase is the first line of a password
store entry. The bootstrap joins whichever is in range:

  flash-tars-bootstrap /dev/disk/by-id/usb-... --network TheShire=wifi/theshire

Log in as jackson over SSH with murph's key, or on the serial console with the
password in the console password entry.

Environment:
  TARS_FLAKE                       the flake to read SSH keys and caches from
                                   (default: the one this app was built from)
  TARS_BOOTSTRAP_IMAGE_URL         the Raspberry Pi OS Lite arm64 image, verified
                                   against the .sha256 published beside it
  TARS_BOOTSTRAP_COUNTRY           Wi-Fi regulatory domain (default US)
  TARS_BOOTSTRAP_CONSOLE_PASSWORD  default tars-bootstrap/console-password
                                   (generated if absent)
USAGE
}

die() {
  echo "flash-tars-bootstrap: $*" >&2
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
    *)
      usage >&2
      die "unknown argument '$1'"
      ;;
  esac
done

if [ ${#networks[@]} -eq 0 ]; then
  die "give at least one --network"
fi

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

step "Reading Wi-Fi passphrases from the password store"
echo '{}' > "$staging/access-points.json"
for network in "${networks[@]}"; do
  ssid=${network%%=*}
  entry=${network#*=}
  passphrase=$(pass show "$entry" | head -n 1)
  jq --arg ssid "$ssid" --arg passphrase "$passphrase" \
    '.[$ssid] = { password: $passphrase }' \
    "$staging/access-points.json" > "$staging/access-points.next.json"
  mv "$staging/access-points.next.json" "$staging/access-points.json"
done

if ! pass show "$console_entry" >/dev/null 2>&1; then
  step "Generating a console password ($console_entry)"
  pass generate -n "$console_entry" 24 >/dev/null
fi
pass show "$console_entry" | head -n 1 | mkpasswd -m yescrypt -s > "$staging/console-password"

step "Reading SSH keys and binary caches from tars-installer"
installer="$flake#nixosConfigurations.tars-installer.config"
nix eval --json "$installer.personal.sshAuthorizedKeys" > "$staging/keys.json"
substituters=$(nix eval --raw "$installer.nix.settings.substituters" --apply 'builtins.concatStringsSep " "')
trusted_keys=$(nix eval --raw "$installer.nix.settings.trusted-public-keys" --apply 'builtins.concatStringsSep " "')

step "Downloading $(basename "$image_url")"
image_xz="$staging/$(basename "$image_url")"
curl --fail --location --show-error --output "$image_xz" "$image_url"
curl --fail --location --show-error --silent --output "$image_xz.sha256" "$image_url.sha256"
(cd "$staging" && sha256sum --check --quiet "$(basename "$image_xz").sha256")
image=${image_xz%.xz}
xz --decompress --threads=0 "$image_xz"

# JSON is valid YAML, and jq quotes passphrases and keys correctly where
# hand-written YAML would not.
step "Writing cloud-init configuration"
cat > "$staging/nix.conf" <<NIXCONF
experimental-features = nix-command flakes
trusted-users = root jackson
substituters = $substituters
trusted-public-keys = $trusted_keys
NIXCONF

# One command, and the last, because cloud-init runs runcmd as a single script
# without -e and reports only its final exit status.
cat > "$staging/install-nix" <<INSTALL
set -eu
# cloud-init runs runcmd without HOME, and the Nix installer refuses to start.
export HOME=/root
curl -fsSL -o /tmp/install-nix https://releases.nixos.org/nix/nix-$nix_version/install
sh /tmp/install-nix --daemon --yes --nix-extra-conf-file /etc/nix-extra.conf
# ssh runs remote commands without a login shell, so nix-daemon and nix-store
# would not be on PATH for ssh-ng:// or for ssh <cmd>.
ln -sf /nix/var/nix/profiles/default/bin/* /usr/local/bin/
INSTALL

{
  echo '#cloud-config'
  jq -n \
    --arg hostname "$hostname" \
    --slurpfile keys "$staging/keys.json" \
    --rawfile passwd "$staging/console-password" \
    --rawfile nixconf "$staging/nix.conf" \
    --rawfile install "$staging/install-nix" \
    '{
      hostname: $hostname,
      # Otherwise sudo cannot resolve the new host name and complains on every
      # use.
      manage_etc_hosts: true,
      users: [{
        name: "jackson",
        groups: "sudo",
        shell: "/bin/bash",
        # For the serial console only; SSH still takes keys alone.
        lock_passwd: false,
        passwd: ($passwd | rtrimstr("\n")),
        sudo: "ALL=(ALL) NOPASSWD:ALL",
        ssh_authorized_keys: $keys[0]
      }],
      ssh_pwauth: false,
      packages: ["tmux"],
      write_files: [{
        path: "/etc/nix-extra.conf",
        content: $nixconf,
        permissions: "0644"
      }],
      runcmd: [
        ["systemctl", "enable", "--now", "ssh"],
        ["sh", "-c", $install]
      ]
    }'
} > "$staging/user-data"

jq -n \
  --arg country "$country" \
  --slurpfile access_points "$staging/access-points.json" \
  '{
    network: {
      version: 2,
      ethernets: { eth0: { dhcp4: true, optional: true } },
      wifis: {
        wlan0: {
          dhcp4: true,
          optional: false,
          "regulatory-domain": $country,
          "access-points": $access_points[0]
        }
      }
    }
  }' > "$staging/network-config"

step "Writing to the image's boot partition"
boot_offset=$(sfdisk -J "$image" |
  jq '.partitiontable.partitions[0].start * (.partitiontable.sectorsize // 512)')
boot="$image@@$boot_offset"
mdir -i "$boot" ::cmdline.txt >/dev/null
# The kernel command line already names serial0 as a console. On a Pi 5 that is
# the debug connector unless uart0_console moves it to GPIO 14/15, where the
# FT232R is wired.
mtype -i "$boot" ::config.txt > "$staging/config.txt"
if ! grep -q '^dtparam=uart0_console' "$staging/config.txt"; then
  printf '\n[all]\nenable_uart=1\ndtparam=uart0_console\n' >> "$staging/config.txt"
fi
for file in user-data network-config config.txt; do
  mcopy -o -i "$boot" "$staging/$file" "::$file"
done

cat <<EOF

About to erase $disk and write Raspberry Pi OS to it.

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

step "Done. Boot the Pi from $target with no other USB disk or SD card attached."

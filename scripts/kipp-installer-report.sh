# Runs on the kipp installer at every boot and writes what it finds to the
# stick it booted from. kipp has no display and no serial console, so when the
# installer never shows up on the network this is the only account of why:
# pull the stick, plug it into murph, and read /report on its root partition.
# No report at all means the firmware never booted the stick.
#
# Nothing here may stop the rest: every command is allowed to fail, and its
# error lands in the file where its output would have been.

set -uo pipefail

reports=/report
mkdir -p "$reports"

# The clock of a machine found in a basement is not to be trusted, and neither
# is a network-less boot to correct it, so boots are numbered, not dated.
last=$(find "$reports" -maxdepth 1 -name 'boot-*' -printf '%f\n' | sed 's/^boot-0*//' | sort -n | tail -n 1)
boot=$(printf '%s/boot-%03d' "$reports" $((${last:-0} + 1)))
mkdir -p "$boot"

capture() {
  local file=$1
  shift
  "$@" > "$file" 2>&1 || echo "[exit $?] $*" >> "$file"
}

# What the machine is. Collected once: none of it changes while it runs.
hardware() {
  local dir=$boot/hardware
  mkdir -p "$dir"
  capture "$dir/hardware-configuration.nix" nixos-generate-config --show-hardware-config --no-filesystems
  capture "$dir/lscpu" lscpu
  capture "$dir/memory" free -h
  capture "$dir/lsblk" lsblk -o NAME,SIZE,TYPE,TRAN,MODEL,SERIAL,FSTYPE,LABEL,MOUNTPOINTS
  capture "$dir/disk-by-id" ls -l /dev/disk/by-id
  capture "$dir/lspci" lspci -nnk
  capture "$dir/lsusb" lsusb
  capture "$dir/dmidecode" dmidecode
  if [ -d /sys/firmware/efi ]; then
    echo "UEFI" > "$dir/firmware-mode"
    capture "$dir/secure-boot" mokutil --sb-state
    capture "$dir/efibootmgr" efibootmgr -v
  else
    echo "legacy BIOS (or UEFI with the compatibility module)" > "$dir/firmware-mode"
  fi
}

# What the network is doing, which does change: taken several times so that a
# Wi-Fi association that is slow, or that comes and goes, can be told apart
# from one that never happens.
network() {
  local dir=$boot/network-$1
  mkdir -p "$dir"
  capture "$dir/uptime" uptime
  capture "$dir/ip-link" ip -br link
  capture "$dir/ip-address" ip -br address
  capture "$dir/ip-route" ip route
  capture "$dir/rfkill" rfkill
  capture "$dir/nmcli-device" nmcli device
  capture "$dir/nmcli-connection" nmcli connection show
  capture "$dir/nmcli-wifi-list" nmcli device wifi list
  capture "$dir/networkmanager-journal" journalctl -b --no-pager -u NetworkManager -u wpa_supplicant
  capture "$dir/dmesg" dmesg
  sync
}

hardware
network 0-at-boot

# Three short beeps: the stick booted and the report is on it. Someone standing
# at the machine learns that within a minute of pressing the power button. Not
# every board wires a speaker to pcspkr, so silence proves nothing; the report
# does. pcspkr is blacklisted, which systemd-modules-load honours and modprobe
# by name does not.
modprobe pcspkr 2>/dev/null || true
beep -f 1000 -l 150 -r 3 2>/dev/null || true

sleep 120
network 1-after-2-minutes
sleep 480
network 2-after-10-minutes

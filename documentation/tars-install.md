# Tars install

> "A giant, sarcastic robot. What a great idea."

`tars` is a Raspberry Pi 5 home server. Like the `case` configuration, it is
really configuration for a class of machines, not a single machine. The idea is
"cattle not pets". However, the first use for a `tars` machine is to attach it
to a USB hard drive and have it store pictures, and managing those disks with
Disko means treating that part more like a pet: Disko needs the exact by-id path
of each drive, and ZFS needs `networking.hostId`, both at evaluation time. The
solution is to split the configuration into content which is reusable for every
`tars` machine, and instance-specific configuration, which right now consists
of:

- `networking.hostName`, which is also the tailnet name
- `networking.hostId`, which ZFS records in the pool
- `tars.disks.root`, the by-id path of the drive Disko puts root on
- any other drive and its Disko layout, which for `tars1` is the EasyStore in
  `nix/modules/hosts/tars1/easystore.nix`

`nix/hosts/tars1.nix` is the first of these; a second would be `tars2.nix`, etc.
The remaining state for a `tars` machine is provisioned during
installation. Secrets are kept in the password store under a prefix matching the
instance host name, and the sections below show how to create each required
secret.

## Preliminaries

Installing will require:

- murph
- A Raspberry Pi 5 and a 27W supply (Make sure to use the right power supply!
  Using the wrong one will cause potentially unbounded confusion. Also, a weaker
  power supply won't work well with powering the WD EasyStore for `tars1`).
- An SD card for the filesystem root, and any other drives the `tars` machine
  will use.
- A spare USB stick for the installer, 8G or larger, since the image is 4.7G
  (USB 3 for speed if you can).
- If no `tars` machine is running to build the installer, a second stick for a
  temporary installer bootstrap.
- The red UART serial adapter from past EE classes (FT232R, optional, for when
  network isn't working).
- Access to the Tailscale admin console.

The commands below write `<bootstrap-stick>` and `<installer-stick>` for the
sticks' by-id paths. The two used so far, as they appear on murph and on the
Raspberry Pi:

- SanDisk: `/dev/disk/by-id/usb-USB_SanDisk_3.2Gen1_03022127073025060850-0:0`
- PNY: `/dev/disk/by-id/usb-PNY_USB_3.2.1_FD_591220716802-0:0`

### Serial console

The serial console over UART is the only way into the Raspberry Pi without a
network. To wire up the UART serial connection, look at [this
diagram](https://pinout.xyz/pinout/uart). Make sure to wire transmit to receive
and vice versa.

| FT232R | Pi header           |
| ------ | ------------------- |
| GND    | pin 6, ground       |
| RX     | pin 8, GPIO 14 TXD  |
| TX     | pin 10, GPIO 15 RXD |
| VCC    | not connected       |

To talk over the serial port on murph:

```sh
nix run nixpkgs#picocom -- -b 115200 \
  /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A5069RR4-if00-port0
```

Make sure your user is a member of `dialout` group, or this will require
`sudo`. This is already done on `murph`. Also, make sure not to have two
programs talking to the port at the same time. Quit `picocom` (`ctrl-a ctrl-x`)
before having an agent talk to it for example.

### Wi-Fi passphrases

The bootstrap and the install read Wi-Fi passphrases from the password
store. Create an entry for any network a `tars` machine should know so the
installer script can use it later:

```sh
pass insert wifi/theshire
pass insert wifi/circlemr1
```

## Flash the installer bootstrap

Note: this is not required if you already have a working `tars` machine up. If
so, skip this section and use it as a builder in the next section. Otherwise,
read on.

The Raspberry Pi NixOS installer image needs to have been built on an aarch64
machine. Two problems: `github:nvmd/nixos-raspberrypi` publishes no prebuilt
installer image (AFAICT), and building an aarch64 package through emulation on
murph took forever last time I tried it. I don't have any other ARM machines, so
the strategy is to flash a Raspberry Pi OS Lite image with the stuff we need,
install Nix on it, and get it to build the Raspberry Pi NixOS installer image
for us.

Raspberry Pi OS uses cloud-init to configure state during first boot from data
on its boot partition. We use this mechanism to set up a `jackson` user that
accepts murph's SSH key and has a console password for serial console logins,
Wi-Fi, and Nix with the same binary caches as the eventual `tars` machine. The
`flashTarsBootstrap` script downloads the image, checks it against its published
checksum, writes all this configuration, and flashes the stick. Each `--network`
flag to the script configures a Wi-Fi network whose passphrase is the first line
of a password store entry.

```sh
nix run .#flashTarsBootstrap -- <bootstrap-stick> \
  --network TheShire=wifi/theshire --network CircleMR1=wifi/circlemr1
```

It asks you to type out the device path for confirmation, and calls `sudo` for
the write, which prompts for a password.

Once you have flashed, insert the bootstrap stick into the Raspberry Pi, making
sure no other storage device is attached, especially an SD card. Booting from
the SanDisk with the EasyStore attached to a USB 3 port has been observed to
hang the bootloader, and the SD card has a higher priority in the boot order.

The first boot takes about a minute, while cloud-init installs Nix, and ends at
a login prompt on the serial console that shows the bootstrap's IP address. Use
that address in place of `tars-bootstrap.local` if the name does not resolve.

Every flash generates new host keys, so drop the old ones first, or `ssh`
refuses to connect with a warning that the host key has changed. The
`ssh-keygen` program does not read the SSH client configuration, so on murph it
has to be told where the `known_hosts` file is located:

```sh
ssh-keygen -R tars-bootstrap.local -f ~/local/hacks/ssh/known_hosts/known_hosts
```

Then wait until cloud-init finishes and Nix is installed:

```sh
ssh jackson@tars-bootstrap.local cloud-init status --wait --long
ssh jackson@tars-bootstrap.local nix --version
```

If things work, you might get something that looks like this, with your own
address and fingerprint, which change with every flash:

```
> ssh jackson@tars-bootstrap.local cloud-init status --wait --long
The authenticity of host 'tars-bootstrap.local (10.0.0.13)' can't be established.
ED25519 key fingerprint is: SHA256:umGgl0EM6VJ7YhtVXoVuFL4hmviPgihDlydvFAOdxWo
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'tars-bootstrap.local' (ED25519) to the list of known hosts.
status: done
extended_status: degraded done
boot_status_code: enabled-by-generator
last_update: Thu, 01 Jan 1970 00:01:46 +0000
detail: DataSourceNoCloud [seed=ds_config_seedfrom,file:///boot/firmware][dsmode=local]
errors: []
recoverable_errors:
WARNING:
	- Could not find module named cc_netplan_nm_patch (searched ['cc_netplan_nm_patch', 'cloudinit.config.cc_netplan_nm_patch'])

> ssh jackson@tars-bootstrap.local nix --version
nix (Nix) 2.35.2
```

The first few lines are SSH's familiar process of determining the host
identity. In the `cloud-init status` output, the warning is about a module that
Raspberry Pi OS lists in its `cloud.cfg` but that Debian's plain trixie
cloud-init doesn't include. It doesn't matter, we don't need it. Then in
`extended_status: degraded done`, "done" means every stage of the cloud-init
process finished, and "degraded" is just recording the occurrence of that
warning, nothing else to worry about. Finally, `detail: DataSourceNoCloud
[seed=ds_config_seedfrom,file:///boot/firmware][dsmode=local]` just means that
it read initialization information from a local file instead of from a cloud
metadata service.

If something goes wrong, log in at the serial console as `jackson` with `pass
tars-bootstrap/console-password`.

## Flash the installer

The `flashTarsInstaller` script builds the image on a builder, copies it back,
and flashes it to a USB stick. The script modifies nixos-raspberrypi's Pi 5
installer by enabling root SSH access for murph's key, NetworkManager for Wi-Fi
in place of iwd, and the serial console on the GPIO header. The builder is
`jackson@tars-bootstrap.local` from above, or a running `tars` machine such as
`jackson@tars1`, which for a reinstall can be the machine about to be erased.
Each `--network` is a Wi-Fi network the installer joins on boot, read from the
password store like the bootstrap flash script.

```sh
nix run .#flashTarsInstaller -- <installer-stick> \
  --builder jackson@tars-bootstrap.local \
  --network TheShire=wifi/theshire --network CircleMR1=wifi/circlemr1
```

Last time, the build took about 15 minutes on a USB 3 stick, most of it writing
and compressing the ext4 image. If you have already built once, the build is
cached, so running the flash script will be much faster and only costs the
amount of time needed to perform the network copy. If the connection drops
mid-build, run it again. The `dd` command can look like it is hanging, but just
let it cook and it will finish in a few minutes.

Once the stick is flashed, we don't need the bootstrap anymore. Go ahead and
power off the Raspberry Pi 5 for the next step.

## Boot the installer

Make sure to boot with the SD card removed, for the same reason as the
boostrap.

Forget the old SSH identity again:

```sh
ssh-keygen -R tars-installer.local -f ~/local/hacks/ssh/known_hosts/known_hosts
```

The installer joins Wi-Fi using the network profiles the flash command wrote
onto the stick, and should be available as `tars-installer.local` over mDNS in a
few minutes. Log in as root:

```sh
ssh root@tars-installer.local
```

If the hostname is unreachable, log in on the serial console with `picocom` and
debug. You can manually connect to a Wi-Fi network with `nmcli device wifi
connect <ssid> --ask`.

Once it is up, insert an SD card that you'd like to use as the filesystem root
for the installation. It should appear as something like `/dev/mmcblk0` in a few
seconds.

```sh
lsblk -o NAME,SIZE,TRAN,MODEL /dev/mmcblk0
```

Check that the root partition grew to fill the stick:

```sh
df -h /
```

The installer attempts to grow the root partition to fill the whole USB stick
space on first boot. However, their is an issue with the
`expand-root-partition.service` where it might not succeed if the device path is
not `sda`. If `/` is still under 4G, grow it manually, because otherwise there
will be too little space for nixos-anywhere to run:

```sh
echo ",+" | sfdisk --no-reread -N 2 <installer-stick>
partx -u <installer-stick>
resize2fs <installer-stick>-part2
```

Also attach any other drives the installed machine will use at this point
(e.g. the EasyStore for `tars1`).

## Write configuration for the new machine

Skip this section when reinstalling a machine that already has per-instance
configuration.

The instance configuration needs to specify the drive paths with Disko. We can
get them by plugging them into the Raspberry Pi with the installer image booted
and querying their information:

```sh
ssh root@tars-installer.local 'lsblk -o NAME,SIZE,TRAN,MODEL,SERIAL; ls -l /dev/disk/by-id'
```

For example, `tars1` is configured to use a WD EasyStore USB hard
drive. Typically, several by-id links will point at the same drive. With the
EasyStore, the by-id listing looks like this:

```
total 0
lrwxrwxrwx 1 root root  9 Sep 19 00:24 ata-WDC_WD50NDZW-11MR8S1_WD-WX52D41FF8E2 -> ../../sdb
lrwxrwxrwx 1 root root 10 Sep 19 00:24 ata-WDC_WD50NDZW-11MR8S1_WD-WX52D41FF8E2-part1 -> ../../sdb1
lrwxrwxrwx 1 root root 13 Sep 18 23:40 mmc-SD64G_0xda7b8c7a -> ../../mmcblk0
lrwxrwxrwx 1 root root 15 Sep 18 23:40 mmc-SD64G_0xda7b8c7a-part1 -> ../../mmcblk0p1
lrwxrwxrwx 1 root root 15 Sep 18 23:40 mmc-SD64G_0xda7b8c7a-part2 -> ../../mmcblk0p2
lrwxrwxrwx 1 root root 15 Sep 18 23:40 mmc-SD64G_0xda7b8c7a-part3 -> ../../mmcblk0p3
lrwxrwxrwx 1 root root  9 Mar 17  2026 usb-USB_SanDisk_3.2Gen1_03022127073025060850-0:0 -> ../../sda
lrwxrwxrwx 1 root root 10 Mar 17  2026 usb-USB_SanDisk_3.2Gen1_03022127073025060850-0:0-part1 -> ../../sda1
lrwxrwxrwx 1 root root 10 Mar 17  2026 usb-USB_SanDisk_3.2Gen1_03022127073025060850-0:0-part2 -> ../../sda2
lrwxrwxrwx 1 root root  9 Sep 19 00:24 usb-WD_easystore_2647_575835324434314646384532-0:0 -> ../../sdb
lrwxrwxrwx 1 root root 10 Sep 19 00:24 usb-WD_easystore_2647_575835324434314646384532-0:0-part1 -> ../../sdb1
lrwxrwxrwx 1 root root  9 Sep 19 00:24 wwn-0x50014ee2148ccd6c -> ../../sdb
lrwxrwxrwx 1 root root 10 Sep 19 00:24 wwn-0x50014ee2148ccd6c-part1 -> ../../sdb1
```

We want the `ata-` or `wwn-` id--the `usb-` link references the USB-to-ATA
bridge inside the EasyStore. Good practice dictates that we use the id that
references the actual storage medium. If the disk ever moved to a different
enclosure with a different USB-to-ATA bridge, the `usb-` id would no longer
work. For the SD card, use the `mmc-` link, which is built from the card's name
and serial number. In both cases pick the link for the whole disk, not one
ending in `-part`.

Once you have the disk by-id paths written down, generate an 8 hex character host
id that will be unique to the new machine:

```sh
od -A n -t x4 -N 4 /dev/urandom | tr -d ' '
```

If the machine configuration will use an encrypted disk, create its key
beforehand. Once you have created this key for an installation, make sure not to
lose it or overwrite it, or you won't be able to decrypt the data on the disk in
the future. For ZFS, the key needs to be 64 hex characters, and can be generated
and recorded to the password store with:

```sh
nix run nixpkgs#openssl -- rand -hex 32 | pass insert -m <hostname>/<drive name>-key
```

A console password is generated by the install script if it does not exist.

Use `nix/hosts/tars1.nix` as a template for the new configuration. Then add it to
`nixosConfigurations` in `flake.nix`.

## Before every install

The install erases every drive described in the Disko configuration for the
machine, so copy anything worth keeping first.

Create a Tailscale auth key that is not reusable, not ephemeral and
untagged at <https://login.tailscale.com/admin/settings/keys>. The install
script asks for it.

If the machine is already on the tailnet from a previous install, remove it from
the "Machines" page of the admin console. Otherwise the new install will join
the tailnet as something like `tars1-1`, which is lame.

## Install

Run the `installTars` script from the dotfiles checkout on murph, specifying the
machine's name and the installer's mDNS hostname as arguments. Add `--network
SSID=ENTRY` once for each network the machine should be able to connect to. Add
`--disk-key PATH=ENTRY` for every encrypted disk. Here, `PATH` is the path on
the installer that the disk's `keylocation` in the Disko configuration uses
(`/tmp/easystore.key` for the EasyStore), and `ENTRY` is the entry in the
password store containing the encryption key.

```sh
nix run .#installTars -- tars1 tars-installer.local \
  --network CircleMR1=wifi/circlemr1 --network TheShire=wifi/theshire \
  --disk-key /tmp/easystore.key=tars1/easystore-key \
  2>&1 | tee ~/scratch/tars-install.log
```

The script will:

- Check that for each disk encryption key mentioned in the Disko configuration,
  there is a corresponding `--disk-key` argument
- Check the password store for those encryption keys
- Generate a console password in the password store if it does not exist yet
- Ask for the tailnet key
- Check that every drive in the Disko configuration is present
- Copy the Disko script's derivations to the installer
- Stage the tailnet key, the console password hash, and a NetworkManager profile
  for every `--network` argument
- Copy each disk key to its `PATH` on the installer
- Partition and format every drive
- Copy the system's derivations into the new root's store at `/mnt`
- Build the system on the Pi
- Install it
- Reboot

`nixos-anywhere` evaluates the configuration on murph and then builds it on the
Raspberry Pi. The two derivation copies are a workaround: murph's Nix store has
a few paths without content addresses or signatures, and the Raspberry Pi
rejects them unless we run `nix copy --no-check-sigs` first.

The Pi will reboot correctly into the installed system even with the USB stick
attached, because the boot order tries the SD card first. You can remove the
stick after it reboots.

## After the install

The installed machine should be on the tailnet within a minute or two of
booting. Its host keys and possibly its tailnet address are new, so drop the old
entries first:

```sh
ssh-keygen -R tars1 -f ~/local/hacks/ssh/known_hosts/known_hosts
tailscale status | grep tars1 # Drop the old host from the tailnet in the Tailscale console if relevant
ssh tars1
```

Then:

- Disable key expiry for `tars1` in the Tailscale console.
- Delete the consumed auth key. `tailscaled-autoconnect` only reads it when
  the node needs to log in:

  ```sh
  ssh tars1 sudo rm /var/lib/tailscale-authkey
  ```

- Check the pools and services:

  ```sh
  ssh tars1 '
  zpool status -x
  zfs get -H keystatus,mounted easystore/data
  systemctl --failed
  '
  ```

## Updating

Run from murph:

```sh
nixos-rebuild switch --flake .#tars1 \
  --target-host jackson@tars1 --build-host jackson@tars1 --sudo
```

Or run from the `tars` machine, against the pushed revision rather than a local
checkout:

```sh
sudo nixos-rebuild switch --flake github:broughjt/dotfiles#tars1 --refresh
```

The Pi evaluates as well as builds, so nothing is copied from murph, but the
revision has to be pushed first. `--refresh` is what makes Nix see a commit
pushed within the last hour; without it, it reuses its cached resolution of the
branch.

## Recovery

First, you can try to SSH over LAN with `ssh tars1.local`. Use this if the
machine is on the Wi-Fi network but off the tailnet.

If the machine doesn't seem to be connected to a Wi-Fi network, try plugging
into Ethernet.

If you can't get Wi-Fi or Ethernet working, try logging in on the serial console
over UART. Log in as `jackson` with the password from `pass
tars1/console-password`. You can try joining a Wi-Fi network with `sudo nmcli
device wifi connect <ssid> --ask`.

Finally, if the system does not boot at all, you can boot the installer with the
root drive detached, reattach it, and try to fix the system from there:

```sh
zpool import -f -R /mnt zroot
```

Make sure to export the pool again before rebooting into the fixed system, or it
will get rejected during the first boot:

```sh
zpool export zroot
```

If you forget, add `zfs_force=1` to the kernel command line in
`nixos/default/cmdline.txt` on the FIRMWARE partition for one boot.

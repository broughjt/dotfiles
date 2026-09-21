{ config, ... }:

let
  keys = config.personal.sshKeys;
in
{
  personal.sshPublicKey = keys.kipp;
  personal.sshAuthorizedKeys = [
    keys.murph
    keys.iphone
  ];

  # Agents and scripts reach kipp as `ssh kipp command`, which is the case
  # Tailscale SSH serves without the ~/local environment.
  tailscale.ssh = false;

  # kipp is one of my own machines on the home LAN, like a tars and unlike a
  # `case` VM: an untagged tailnet node, with sshd left open on the LAN
  # (openssh.openFirewall defaults to true), key-only as everywhere. That is the
  # way in when the tailnet is what broke, and kipp has no display or serial
  # console to fall back on. Services are for the tailnet only.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Answer as kipp.local, so that way in does not start with a hunt for an
  # address. NetworkManager asks resolved to answer mDNS on every connection it
  # brings up.
  networking.networkmanager.connectionConfig."connection.mdns" = 2;
  networking.firewall.allowedUDPPorts = [ 5353 ];

  # The install stages a tailnet key with nixos-anywhere's --extra-files. Under
  # /persist because the root it would otherwise sit on is rolled back before
  # tailscaled-autoconnect ever runs. See documentation/kipp-install.md.
  services.tailscale.authKeyFile = "/persist/etc/tailscale-authkey";
}

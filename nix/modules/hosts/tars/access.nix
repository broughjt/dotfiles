{ ... }:

{
  # Unlike case, a tars machine has no public address, so sshd stays open on the
  # LAN (openssh.openFirewall defaults to true), key-only as everywhere. It is
  # the way in when the tailnet is what broke: a first boot that fails to
  # enroll, an expired or removed node. Services are for the tailnet only.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Answer as <hostname>.local, so that way in does not start with a hunt for an
  # address. NetworkManager asks resolved to answer mDNS on every connection it
  # brings up.
  networking.networkmanager.connectionConfig."connection.mdns" = 2;
  networking.firewall.allowedUDPPorts = [ 5353 ];

  # The tailnet's DNS is DNS over HTTPS, which needs a roughly correct clock to
  # verify certificates. The Pi 5's clock does not survive a power cut without
  # an RTC battery, and timesyncd needs DNS to find its servers, so a boot with
  # a stale clock would never correct it (observed 2026-09-18). Resolving
  # through the LAN's DNS instead costs MagicDNS names on this machine. Revert
  # this if an RTC battery is ever fitted.
  services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

  # We provision a tailnet key and place it on the filesystem during
  # installation with `nixos-anywhere`'s `--extra-files` flag. See
  # documentation/tars-install.md.
  services.tailscale.authKeyFile = "/var/lib/tailscale-authkey";
}

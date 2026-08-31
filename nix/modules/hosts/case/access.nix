{ ... }:

{
  # Avoid openning port 22 open to the world. Should be reachable over the
  # tailnet only.
  services.openssh.openFirewall = false;

  # The nixpkgs tailscale module does not do this itself: its own openFirewall
  # only opens the WireGuard UDP port. Without the trusted interface, sshd is
  # unreachable over the tailnet as well as off it.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # With port 22 closed, nothing can reach the VM until it is one the
  # tailnet. Joining the tailnet should therefore happen during provisioning. We
  # set up nixos-anywhere to stage a `tailscale-authkey` file (reusable,
  # pre-approved key) with --extra-files.
  # Do not set services.tailscale.authKeyParameters here. The module appends
  # them to the key as URL parameters -- `tailscale up --auth-key "$(cat
  # file)?preauthorized=true"` -- and Tailscale only accepts that form for an
  # OAuth client secret. Appending it to a plain tskey-auth-... key corrupts the
  # key string. Pre-approval and reusability are properties of the key itself,
  # set when it is created in the admin console.
  services.tailscale.authKeyFile = "/var/lib/tailscale-authkey";

  # Tailscale registers the node under whatever hostname is set when
  # `tailscale up` runs, and nixpkgs orders tailscaled-autoconnect only after
  # tailscaled.service. cloud-init sets the hostname from Hetzner's metadata in
  # its pre-networking stage, so the two race: measured on the first boot,
  # autoconnect started at 01:30:27.76 while cloud-init-local did not set the
  # hostname until 01:30:29.79, and the VM joined the tailnet as `nixos`.
  # cloud-init.service is named too because it re-runs update_hostname, which
  # covers a datasource that only resolves once networking is up.
  systemd.services.tailscaled-autoconnect = {
    after = [
      "cloud-init-local.service"
      "cloud-init.service"
    ];
    wants = [ "cloud-init-local.service" ];
  };
}

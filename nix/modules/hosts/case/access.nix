{ ... }:

{
  # Avoid openning port 22 open to the world. Should be reachable over the
  # tailnet only.
  services.openssh.openFirewall = false;

  # The nixpkgs tailscale module does not do this itself: its own openFirewall
  # only opens the WireGuard UDP port. Without the trusted interface, sshd is
  # unreachable over the tailnet as well as off it.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # programs.mosh.openFirewall defaults to true and would open UDP 60000-61000
  # to the world, which is the one thing this file exists to prevent. Unlike
  # Tailscale SSH, mosh-server binds an ordinary kernel UDP socket, so its
  # packets do traverse the firewall; the trusted interface above is what
  # carries them, and no port needs opening for the tailnet path to work.
  programs.mosh.openFirewall = false;

  # With port 22 closed, nothing can reach the VM until it is one the
  # tailnet. Joining the tailnet should therefore happen during provisioning. We
  # set up nixos-anywhere to stage a `tailscale-authkey` file (reusable,
  # pre-approved, ephemeral key) with --extra-files. Ephemeral is what lets a
  # deleted VM remove its own tailnet node; see documentation/case-install.md.
  # Do not set services.tailscale.authKeyParameters here. The module appends
  # them to the key as URL parameters -- `tailscale up --auth-key "$(cat
  # file)?preauthorized=true"` -- and Tailscale only accepts that form for an
  # OAuth client secret. Appending it to a plain tskey-auth-... key corrupts the
  # key string. Reusability, pre-approval and ephemerality are properties of the
  # key itself, set when it is created in the admin console.
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

  # Reaching `case` at all goes through tailscaled, so a tailscaled that will
  # not start is a lost VM: port 22 is closed to the world and the only way
  # back is the Hetzner console. Measured 2026-09-01, when tailscaled's own
  # ipnlocal watchdog reported a deadlock (reportDeadlock in
  # ipn/ipnlocal/watchdog.go) and the daemon then failed to come back.
  # `tailscaled --cleanup` and the start that followed each sat on systemd's
  # 90 second default, so one retry cycle cost three minutes with tailscale0
  # down throughout.
  #
  # This cannot be built on WatchdogSec. tailscaled announces readiness
  # through sd_notify but never sends WATCHDOG=1, so a watchdog would kill a
  # healthy daemon on every interval. Timeouts and the start limit are what
  # is left.
  systemd.services.tailscaled = {
    # A wedged tailscale0 is what makes --cleanup hang, so bound it. This
    # brings a failing cycle down from about three minutes to about two.
    serviceConfig = {
      TimeoutStopSec = 20;
      RestartSec = 5;
    };

    # Five failures inside half an hour means restarting is not going to fix
    # it, and something holding the TUN device is the likely reason. A reboot
    # clears that. /var/lib/tailscale is ordinary disk state on this host, so
    # the node rejoins at the same address; see *Ephemeral tailnet keys* in
    # documentation/case-install.md. An unreachable VM is worth more rebooted
    # than left wedged.
    startLimitIntervalSec = 1800;
    startLimitBurst = 5;
    unitConfig.StartLimitAction = "reboot";
  };
}

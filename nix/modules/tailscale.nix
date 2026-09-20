{ config, lib, ... }:

{
  options.tailscale.ssh = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether tailscaled answers port 22 on the tailnet address itself, letting
      in whichever tailnet nodes the policy names, with no keys. When false,
      OpenSSH answers there as it does everywhere else.

      Tailscale SSH has no PAM stack of its own. It borrows login's for an
      interactive shell on a terminal and nothing's for a command, so
      `ssh host command` runs without what local-directory.nix announces
      through pam_env. A host that agents and scripts drive that way turns this
      off.
    '';
  };

  config.services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";
    # Always stated, never omitted: `tailscale set` changes only the flags it is
    # given, and the preference it last wrote is kept in /var/lib/tailscale.
    extraSetFlags = [ "--ssh=${lib.boolToString config.tailscale.ssh}" ];
  };
}

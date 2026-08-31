{ config, ... }:

{
  system.stateVersion = "25.05";

  # Our intention is for one configuration to serve every `case` VM, so no
  # identity should be baked in. cloud-init reads Hetzner's metadata service and
  # sets the hostname from the name given to `hcloud server create --name`,
  # which is also the name the VM takes on the tailnet. Leaving
  # networking.hostName empty is what lets us hand the decision to
  # cloud-init. nixpkgs' module already sets preserve_hostname false and runs
  # update_hostname.
  networking.hostName = "";

  # cloud-init renders the interface configuration from the same metadata, so
  # nothing here needs to know whether the interface is ens3 or enp1s0, or what
  # the instance's static IPv6 address is.
  services.cloud-init = {
    enable = true;
    network.enable = true;
    # The host keys are generated during the nixos-anywhere install. cloud-init
    # would otherwise delete and regenerate them on first boot, changing the
    # fingerprint out from under known_hosts.
    settings.ssh_deletekeys = false;
  };
  networking.useNetworkd = true;
  networking.useDHCP = false;

  users.users.${config.personal.userName}.uid = 1000;

  # `linux.nix` sets users.mutableUsers = false and `case` deliberately supplies
  # no password, so wheel's default password prompt makes sudo unusable rather
  # than secure -- the account simply has no password to type. Reaching the
  # machine at all already requires a key and the tailnet, which is the real
  # boundary here, so let wheel through without one. Without this an agent on
  # `case` cannot restart a service or rebuild the system.
  security.sudo.wheelNeedsPassword = false;

  i18n.defaultLocale = "en_US.UTF-8";

  # HT Deej
  time.timeZone = "UTC";
}

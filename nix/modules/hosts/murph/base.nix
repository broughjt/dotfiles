{
  config,
  lib,
  ...
}:

{
  system.stateVersion = "25.05";

  networking.hostName = "murph";
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  users.users.${config.personal.userName} = {
    uid = 1000;
    extraGroups = [
      "networkmanager"
      # USB serial adapters, for example for talking to a Raspberry Pi's UART
      # console.
      "dialout"
    ];
  };

  personal.sshPublicKey = config.personal.sshKeys.murph;
  personal.sshAuthorizedKeys = with config.personal.sshKeys; [
    iphone
    sandia
  ];

  # murph's root is ephemeral, so host keys go to the persisted hacks tree; the
  # trailing directory is there because impermanence mounts directories.
  ssh.knownHostsFile = "${config.defaultDirectories.localDirectory}/hacks/ssh/known_hosts/known_hosts";

  programs.ssh.extraConfig = lib.mkBefore ''
    Host s1111508
      HostName localhost
      HostKeyAlias s1111508
      User jtbroug
      Port 2222
      IdentityFile ${config.defaultDirectories.localDirectory}/secrets/ssh/id_ecdsa_nistp256
      IdentitiesOnly yes
      # Hide the sshd legal banner and the post-quantum key exchange warning.
      LogLevel ERROR
  '';

  # The s1111508 machine opens a reverse tunnel open on port 2222 to murph. I
  # had a problem where the port was bound but the connection was dead, and I
  # had to kill the process holding the port. These settings make sure it dies
  # sooner so this kind of thing doesn't happen.
  services.openssh.settings = {
    ClientAliveInterval = 30;
    ClientAliveCountMax = 3;
  };

  # Enable mDNS/DNS-SD for .local hostname resolution and LAN service discovery.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    # Docker's bridge address is unreachable from the LAN.
    settings.server.deny-interfaces = [ "docker0" ];
    settings.publish = {
      disable-publishing = false;
      publish-addresses = true;
    };
  };
  # Enable the resolved systemd service for network name resolution.
  services.resolved = {
    enable = true;
    settings.Resolve.MulticastDNS = false;
  };

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  console.keyMap = "us";

  time.timeZone = "America/Denver";
}

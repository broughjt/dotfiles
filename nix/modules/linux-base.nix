{
  config,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
in
{
  nix.settings.trusted-users = [
    "root"
    user
  ];

  environment.systemPackages = with pkgs; [
    curl
    git
    neovim
    glibcInfo
    man-pages
  ];
  environment.shells = with pkgs; [
    bashInteractive
    fish
  ];

  programs.fish.enable = true;

  users.mutableUsers = false;

  users.users.${user} = {
    isNormalUser = true;
    description = config.personal.fullName;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [ config.personal.sshPublicKey ];
  };

  services.openssh.enable = true;

  # OpenSSH has no XDG-aware user configuration path, and Home Manager always
  # writes ~/.ssh/config. Keep the personal user's store-backed client policy in
  # the system configuration instead of creating a top-level home dotfile.
  programs.ssh.extraConfig = ''
    Match localuser ${user}
      AddKeysToAgent yes
      IdentityFile ${localDirectory}/secrets/ssh/id_ed25519
      UserKnownHostsFile ${localDirectory}/hacks/ssh/known_hosts/known_hosts
  '';

  security.sudo.extraConfig = ''
    Defaults:${user} lecture=never
  '';

  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}

{
  config,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
in
{
  environment.systemPackages = with pkgs; [
    curl
    git
    neovim
    glibcInfo
    man-pages
    # Ghostty breaks TMUX on terminals without this
    ghostty.terminfo
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

  # Mosh belongs beside sshd rather than in a package list: it is a login path,
  # not a program. It bootstraps by running mosh-server over SSH and then speaks
  # its own UDP protocol, which is what lets a session survive the client
  # roaming between networks or sleeping. A phone does both constantly.
  #
  # openFirewall defaults to true and opens UDP 60000-61000 on every interface.
  # That matches what openssh.openFirewall already does for port 22 here, so
  # this adds no exposure a host did not already have. A host that closes sshd
  # to the world closes this too.
  programs.mosh.enable = true;

  security.sudo.extraConfig = ''
    Defaults:${user} lecture=never
  '';
}

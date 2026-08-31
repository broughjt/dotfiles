{
  config,
  lib,
  ...
}:

let
  user = config.personal.userName;
  uid = config.users.users.${user}.uid;
  homeDirectory = config.defaultDirectories.homeDirectory;
  localDirectory = config.defaultDirectories.localDirectory;
  xdgEnvironment = {
    XDG_BIN_HOME = "${localDirectory}/bin";
    XDG_CACHE_HOME = "${localDirectory}/cache";
    XDG_CONFIG_HOME = "${localDirectory}/config";
    XDG_DATA_HOME = "${localDirectory}/share";
    XDG_STATE_HOME = "${localDirectory}/state";
  };
  pamXdgEnvironment = xdgEnvironment // {
    GNUPGHOME = "${xdgEnvironment.XDG_DATA_HOME}/gnupg";
  };
  pamXdgEnvironmentFile = "/etc/pam/${user}-xdg-environment";
  pamValue =
    value:
    if lib.hasPrefix homeDirectory value then
      "@{HOME}" + lib.removePrefix homeDirectory value
    else
      value;
  pamXdgEnvironmentText =
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: ''${name} DEFAULT="${pamValue value}"'') pamXdgEnvironment
    )
    + "\n";
  makePamXdgEnvironmentRules = gnomeKeyringRule: {
    skip_xdg_environment_for_other_users = {
      order = gnomeKeyringRule.order - 11;
      control = "[success=1 default=ignore]";
      modulePath = "${config.security.pam.package}/lib/security/pam_succeed_if.so";
      args = [
        "quiet"
        "user"
        "!="
        user
      ];
    };
    xdg_environment = {
      order = gnomeKeyringRule.order - 10;
      control = "required";
      modulePath = "${config.security.pam.package}/lib/security/pam_env.so";
      settings = {
        conffile = pamXdgEnvironmentFile;
        readenv = 0;
      };
    };
  };
  userEnvironment = xdgEnvironment // {
    GNUPGHOME = "${localDirectory}/share/gnupg";
  };
in
{
  # The NixOS half of the ~/local layout. home/local-directory.nix states the
  # same layout inside Home Manager; this half is what PAM and the systemd user
  # manager announce, and what exists before Home Manager has run.
  assertions = [
    {
      assertion = uid != null;
      message = "localDirectory requires an explicit UID for ${user}";
    }
  ];

  systemd.services."user@${toString uid}" = {
    overrideStrategy = "asDropin";
    environment = userEnvironment;
  };

  systemd.services."home-manager-${user}".environment = userEnvironment;

  # These are read by pam_env before the graphical session and some
  # PAM-started helpers exist. In particular, pam_gnome_keyring starts an early
  # `gnome-keyring-daemon --login` before the systemd user manager's environment
  # can help; it must see XDG_DATA_HOME here to avoid falling back to
  # ~/.local/share/keyrings. Keep this scoped to the personal user: non-matching
  # users skip the following pam_env rule.
  environment.etc."pam/${user}-xdg-environment".text = pamXdgEnvironmentText;
  security.pam.services.login.rules.session = makePamXdgEnvironmentRules (
    config.security.pam.services.login.rules.session.gnome_keyring
  );

  systemd.tmpfiles.rules = [
    "d ${localDirectory} 0755 ${user} users -"
    "d ${localDirectory}/bin 0755 ${user} users -"
    "d ${localDirectory}/config 0755 ${user} users -"
    "d ${localDirectory}/cache 0700 ${user} users -"
    "d ${localDirectory}/share 0755 ${user} users -"
    "d ${localDirectory}/state 0755 ${user} users -"
  ];
}

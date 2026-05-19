{ config, lib, ... }:

let
  user = config.personal.userName;
  uid = toString config.users.users.${user}.uid;
  profile = user;
  emptyStringArray = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
  workspaceNumbers = lib.range 1 9;
  workspaceKeybindings = lib.mergeAttrsList (
    map (
      n:
      let
        i = toString n;
      in
      {
        "switch-to-workspace-${i}" = [ "<Super>${i}" ];
        "move-to-workspace-${i}" = [ "<Super><Shift>${i}" ];
      }
    ) workspaceNumbers
  );
  disabledApplicationKeybindings = lib.genAttrs (map (
    n: "switch-to-application-${toString n}"
  ) workspaceNumbers) (_: emptyStringArray);
  lockedDconfKeys = [
    # Workspace model.
    "/org/gnome/mutter/dynamic-workspaces"
    "/org/gnome/desktop/wm/preferences/num-workspaces"

    # Custom window-management shortcuts.
    "/org/gnome/desktop/wm/keybindings/close"
  ]
  ++ lib.concatMap (
    n:
    let
      i = toString n;
    in
    [
      "/org/gnome/desktop/wm/keybindings/switch-to-workspace-${i}"
      "/org/gnome/desktop/wm/keybindings/move-to-workspace-${i}"
      # Keep Super+number available for workspace switching instead of the
      # GNOME Shell dash/application shortcuts.
      "/org/gnome/shell/keybindings/switch-to-application-${i}"
    ]
  ) workspaceNumbers;
in
{
  programs.dconf = {
    enable = true;

    # Keep GNOME defaults declarative without writing them to the mutable user
    # dconf database. Only this user's session opts into this profile via
    # DCONF_PROFILE below.
    profiles.${profile}.databases = [
      {
        # Lock only the keys that are structural invariants. Other settings,
        # such as color-scheme, remain user-overridable for the current boot and
        # fall back to these declarative defaults after reboot.
        locks = lockedDconfKeys;
        settings = {
          "org/gnome/desktop/wm/keybindings" = {
            close = [ "<Super>q" ];
          }
          // workspaceKeybindings;
          "org/gnome/desktop/wm/preferences" = {
            num-workspaces = lib.gvariant.mkInt32 9;
          };
          "org/gnome/shell/keybindings" = {
            toggle-message-tray = emptyStringArray;
            focus-active-notification = emptyStringArray;
            toggle-overview = emptyStringArray;
          }
          // disabledApplicationKeybindings;
          "org/gnome/mutter" = {
            # Keep a fixed set of workspaces; num-workspaces is ignored while
            # dynamic workspaces are enabled.
            dynamic-workspaces = false;
          };
          "org/gnome/mutter/keybindings" = {
            switch-monitor = emptyStringArray;
          };
          "org/gnome/shell" = {
            disable-user-extensions = false;
            disabled-extensions = emptyStringArray;
          };
          "org/gnome/desktop/interface" = {
            scaling-factor = lib.gvariant.mkUint32 2;
            color-scheme = "prefer-dark";
            font-name = "Inter 11";
            document-font-name = "Inter 11";
            monospace-font-name = "JuliaMono 11";
            enable-hot-corners = false;
            clock-format = "12h";
          };
          "org/gnome/desktop/background" = {
            picture-options = "none";
            color-shading-type = "solid";
            primary-color = "#0a369d";
          };
          "org/gnome/settings-daemon/plugins/housekeeping" = {
            donation-reminder-enabled = false;
          };
        };
      }
    ];
  };

  systemd.services."user@${uid}" = {
    overrideStrategy = "asDropin";
    environment.DCONF_PROFILE = profile;
  };
}

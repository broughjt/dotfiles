{ config, lib, ... }:

let
  user = config.personal.userName;
  uid = toString config.users.users.${user}.uid;
  profile = user;
  emptyStringArray = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
in
{
  programs.dconf = {
    enable = true;

    # Keep GNOME defaults declarative without writing them to the mutable user
    # dconf database. Only this user's session opts into this profile via
    # DCONF_PROFILE below.
    profiles.${profile}.databases = [
      {
        lockAll = true;
        settings = {
          "org/gnome/desktop/wm/keybindings" = {
            close = [ "<Super>q" ];
            switch-to-workspace-1 = [ "<Super>1" ];
            switch-to-workspace-2 = [ "<Super>2" ];
            switch-to-workspace-3 = [ "<Super>3" ];
            switch-to-workspace-4 = [ "<Super>4" ];
            switch-to-workspace-5 = [ "<Super>5" ];
            switch-to-workspace-6 = [ "<Super>6" ];
            switch-to-workspace-7 = [ "<Super>7" ];
            switch-to-workspace-8 = [ "<Super>8" ];
            switch-to-workspace-9 = [ "<Super>9" ];
            move-to-workspace-1 = [ "<Super><Shift>1" ];
            move-to-workspace-2 = [ "<Super><Shift>2" ];
            move-to-workspace-3 = [ "<Super><Shift>3" ];
            move-to-workspace-4 = [ "<Super><Shift>4" ];
            move-to-workspace-5 = [ "<Super><Shift>5" ];
            move-to-workspace-6 = [ "<Super><Shift>6" ];
            move-to-workspace-7 = [ "<Super><Shift>7" ];
            move-to-workspace-8 = [ "<Super><Shift>8" ];
            move-to-workspace-9 = [ "<Super><Shift>9" ];
          };
          "org/gnome/desktop/wm/preferences" = {
            num-workspaces = lib.gvariant.mkInt32 9;
          };
          "org/gnome/shell/keybindings" = {
            toggle-message-tray = emptyStringArray;
            focus-active-notification = emptyStringArray;
            toggle-overview = emptyStringArray;
            switch-to-application-1 = emptyStringArray;
            switch-to-application-2 = emptyStringArray;
            switch-to-application-3 = emptyStringArray;
            switch-to-application-4 = emptyStringArray;
            switch-to-application-5 = emptyStringArray;
            switch-to-application-6 = emptyStringArray;
            switch-to-application-7 = emptyStringArray;
            switch-to-application-8 = emptyStringArray;
            switch-to-application-9 = emptyStringArray;
          };
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
        };
      }
    ];
  };

  systemd.services."user@${uid}" = {
    overrideStrategy = "asDropin";
    environment.DCONF_PROFILE = profile;
  };
}

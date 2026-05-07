{ home-manager }:

{ config, lib, ... }:

{
  home-manager.users.${config.personal.userName}.dconf = {
    enable = true;
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
        num-workspaces = 9;
      };
      "org/gnome/shell/keybindings" = {
        toggle-message-tray = [ ];
        focus-active-notification = [ ];
        toggle-overview = [ ];
        switch-to-application-1 = [ ];
        switch-to-application-2 = [ ];
        switch-to-application-3 = [ ];
        switch-to-application-4 = [ ];
        switch-to-application-5 = [ ];
        switch-to-application-6 = [ ];
        switch-to-application-7 = [ ];
        switch-to-application-8 = [ ];
        switch-to-application-9 = [ ];
      };
      "org/gnome/mutter/keybindings" = {
        switch-monitor = [ ];
        dynamic-workspaces = true;
      };
      "org/gnome/shell" = {
        disabled-user-extension = false;
        disabled-extensions = "disabled";
      };
      "org/gnome/desktop/interface" = {
        scaling-factor = home-manager.lib.hm.gvariant.mkUint32 2;
        color-scheme = "prefer-dark";
        enable-hot-cornors = false;
        clock-format = "12h";
      };
      "org/gnome/desktop/background" = {
        picture-options = "none";
        color-shading-type = "solid";
        primary-color = "#0a369d";
      };
    };
  };
}

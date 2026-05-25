{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;

  todoistStateDir = "${localDirectory}/state/todoist-electron";
  todoistProfileDir = "${todoistStateDir}/profile";
  todoistCacheDir = "${localDirectory}/cache/todoist-electron";
  todoistEphemeralProfileDirs = [
    "blob_storage"
    "Cache"
    "Code Cache"
    "Crashpad"
    "DawnGraphiteCache"
    "DawnWebGPUCache"
    "Dictionaries"
    "GPUCache"
    "logs"
    "sentry"
    "Shared Dictionary"
  ];

  tmpfilesEscape = lib.replaceStrings [ " " ] [ "\\x20" ];

  todoistElectronPackage = pkgs.symlinkJoin {
    name = "todoist-electron-local-state";
    paths = [ pkgs.todoist-electron ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f "$out/bin/todoist-electron"
      makeWrapper ${pkgs.todoist-electron}/bin/todoist-electron "$out/bin/todoist-electron" \
        --add-flags ${lib.escapeShellArg "--user-data-dir=${todoistProfileDir}"}
    '';
  };
in
{
  # Todoist Electron stores both application state and Chromium cache data in
  # one Electron userData directory by default ($XDG_CONFIG_HOME/Todoist). Point
  # it at an explicit profile directory, persist that profile with impermanence,
  # and symlink the bulky/rebuildable subdirectories back to ephemeral cache.
  # The remaining profile contains login/session data, cookies, local/offline web
  # storage, window state, and user preferences.
  system.activationScripts.prepareTodoistElectronProfile = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg todoistStateDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg todoistProfileDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg todoistCacheDir}
    ''
    + lib.concatMapStringsSep "\n" (name: ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg "${todoistCacheDir}/${name}"}
      rm -rf ${lib.escapeShellArg "${todoistProfileDir}/${name}"}
      ln -sfn ${lib.escapeShellArg "${todoistCacheDir}/${name}"} ${lib.escapeShellArg "${todoistProfileDir}/${name}"}
    '') todoistEphemeralProfileDirs;
  };

  systemd.tmpfiles.rules = [
    "d ${todoistStateDir} 0700 ${user} users -"
    "d ${todoistProfileDir} 0700 ${user} users -"
    "d ${todoistCacheDir} 0700 ${user} users -"
  ]
  ++ map (
    name: "d ${tmpfilesEscape "${todoistCacheDir}/${name}"} 0700 ${user} users -"
  ) todoistEphemeralProfileDirs
  ++ map (
    name:
    "L+ ${tmpfilesEscape "${todoistProfileDir}/${name}"} - - - - ${tmpfilesEscape "${todoistCacheDir}/${name}"}"
  ) todoistEphemeralProfileDirs;

  home-manager.users.${user}.home.packages = [
    todoistElectronPackage
  ];
}

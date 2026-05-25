{ llmAgentsOverlay }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;

  chromiumStateDir = "${localDirectory}/state/chromium";
  chromiumProfileDir = "${chromiumStateDir}/profile";
  chromiumCacheDir = "${localDirectory}/cache/chromium";
  chromiumDiskCacheDir = "${chromiumCacheDir}/disk-cache";
  chromiumProfileCacheDir = "${chromiumCacheDir}/profile";
  chromiumPkiDir = "${localDirectory}/share/pki/nssdb";

  chromiumEphemeralProfileDirs = [
    "Crash Reports"
    "GraphiteDawnCache"
    "GrShaderCache"
    "ShaderCache"
    "Default/Cache"
    "Default/Code Cache"
    "Default/DawnGraphiteCache"
    "Default/DawnWebGPUCache"
    "Default/GPUCache"
    "Default/Shared Dictionary"
  ];

  tmpfilesEscape = lib.replaceStrings [ " " ] [ "\\x20" ];

  chromiumPackage = pkgs.symlinkJoin {
    name = "chromium-local-state";
    paths = [ pkgs.chromium ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in chromium chromium-browser; do
        rm -f "$out/bin/$bin"
        makeWrapper ${pkgs.chromium}/bin/$bin "$out/bin/$bin" \
          --add-flags ${lib.escapeShellArg "--user-data-dir=${chromiumProfileDir}"} \
          --add-flags ${lib.escapeShellArg "--disk-cache-dir=${chromiumDiskCacheDir}"} \
          --add-flags --no-first-run
      done
    '';
  };

  agentBrowserStateDir = "${localDirectory}/state/agent-browser";
  agentBrowserHomeDir = "${agentBrowserStateDir}/home";
  agentBrowserPersistedStateDir = "${agentBrowserHomeDir}/.agent-browser";
  agentBrowserCacheDir = "${localDirectory}/cache/agent-browser";
  agentBrowserConfigDir = "${agentBrowserCacheDir}/config";
  agentBrowserDataDir = "${agentBrowserCacheDir}/share";
  agentBrowserXdgStateDir = "${agentBrowserCacheDir}/state";

  agentBrowserPackage = pkgs.symlinkJoin {
    name = "agent-browser-local-state";
    paths = [ pkgs.agent-browser ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f "$out/bin/agent-browser"
      makeWrapper ${pkgs.agent-browser}/bin/agent-browser "$out/bin/agent-browser" \
        --set HOME ${lib.escapeShellArg agentBrowserHomeDir} \
        --set XDG_CONFIG_HOME ${lib.escapeShellArg agentBrowserConfigDir} \
        --set XDG_CACHE_HOME ${lib.escapeShellArg agentBrowserCacheDir} \
        --set XDG_DATA_HOME ${lib.escapeShellArg agentBrowserDataDir} \
        --set XDG_STATE_HOME ${lib.escapeShellArg agentBrowserXdgStateDir} \
        --set AGENT_BROWSER_HOME ${lib.escapeShellArg agentBrowserPersistedStateDir} \
        --set AGENT_BROWSER_EXECUTABLE_PATH ${lib.escapeShellArg "${pkgs.chromium}/bin/chromium"}
    '';
  };
in
{
  nixpkgs.overlays = [ llmAgentsOverlay ];

  # Chromium's profile contains cookies, logins, extension state, local storage,
  # history, and preferences. Persist it, while pointing HTTP cache at
  # ~/local/cache and symlinking obvious rebuildable Chromium cache subtrees.
  # The NSS DB under XDG_DATA_HOME/pki may hold local certificate trust/client
  # cert decisions, so persist it separately.
  system.activationScripts.prepareBrowserToolsState = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg chromiumStateDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg chromiumProfileDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg chromiumCacheDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg chromiumDiskCacheDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg chromiumProfileCacheDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg chromiumPkiDir}
    ''
    + lib.concatMapStringsSep "\n" (name: ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg "${chromiumProfileCacheDir}/${name}"}
      rm -rf ${lib.escapeShellArg "${chromiumProfileDir}/${name}"}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg (dirOf "${chromiumProfileDir}/${name}")}
      ln -sfn ${lib.escapeShellArg "${chromiumProfileCacheDir}/${name}"} ${lib.escapeShellArg "${chromiumProfileDir}/${name}"}
    '') chromiumEphemeralProfileDirs
    + ''

      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg agentBrowserStateDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg agentBrowserHomeDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg agentBrowserPersistedStateDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg agentBrowserCacheDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg agentBrowserConfigDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg agentBrowserDataDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg agentBrowserXdgStateDir}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${chromiumStateDir} 0700 ${user} users -"
    "d ${chromiumProfileDir} 0700 ${user} users -"
    "d ${chromiumProfileDir}/Default 0700 ${user} users -"
    "d ${chromiumCacheDir} 0700 ${user} users -"
    "d ${chromiumDiskCacheDir} 0700 ${user} users -"
    "d ${chromiumProfileCacheDir} 0700 ${user} users -"
    "d ${chromiumProfileCacheDir}/Default 0700 ${user} users -"
    "d ${chromiumPkiDir} 0700 ${user} users -"
    "d ${agentBrowserStateDir} 0700 ${user} users -"
    "d ${agentBrowserHomeDir} 0700 ${user} users -"
    "d ${agentBrowserPersistedStateDir} 0700 ${user} users -"
    "d ${agentBrowserCacheDir} 0700 ${user} users -"
    "d ${agentBrowserConfigDir} 0700 ${user} users -"
    "d ${agentBrowserDataDir} 0700 ${user} users -"
    "d ${agentBrowserXdgStateDir} 0700 ${user} users -"
  ]
  ++ map (
    name: "d ${tmpfilesEscape "${chromiumProfileCacheDir}/${name}"} 0700 ${user} users -"
  ) chromiumEphemeralProfileDirs
  ++ map (
    name:
    "L+ ${tmpfilesEscape "${chromiumProfileDir}/${name}"} - - - - ${tmpfilesEscape "${chromiumProfileCacheDir}/${name}"}"
  ) chromiumEphemeralProfileDirs;

  # agent-browser normally uses ~/.agent-browser and launches whichever Chrome it
  # discovers. The wrapper gives it a small private HOME under ~/local/state,
  # leaves launched-browser scratch data under ~/local/cache/agent-browser, and
  # points it at Nix-managed Chromium. Named sessions can contain auth cookies and
  # saved localStorage, so only the .agent-browser state subtree is persisted.
  home-manager.users.${user}.home.packages = [
    chromiumPackage
    agentBrowserPackage
  ];
}

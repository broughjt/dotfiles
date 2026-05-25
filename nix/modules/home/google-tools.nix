{ googleWorkspaceCliOverlay }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;

  gcloudConfigDir = "${localDirectory}/config/gcloud";
  gcloudLogsDir = "${localDirectory}/cache/gcloud/logs";

  gwsConfigDir = "${localDirectory}/config/gws";
  gwsLogsDir = "${localDirectory}/cache/gws/logs";

  googleCloudSdkPackage = pkgs.symlinkJoin {
    name = "google-cloud-sdk-local-config";
    paths = [ pkgs.google-cloud-sdk ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in gcloud gsutil bq docker-credential-gcloud git-credential-gcloud.sh; do
        rm -f "$out/bin/$bin"
        makeWrapper ${pkgs.google-cloud-sdk}/bin/$bin "$out/bin/$bin" \
          --set CLOUDSDK_CONFIG ${lib.escapeShellArg gcloudConfigDir}
      done
    '';
  };

  gwsPackage = pkgs.symlinkJoin {
    name = "gws-local-config";
    paths = [ pkgs.gws ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f "$out/bin/gws"
      makeWrapper ${pkgs.gws}/bin/gws "$out/bin/gws" \
        --set GOOGLE_WORKSPACE_CLI_CONFIG_DIR ${lib.escapeShellArg gwsConfigDir} \
        --set GOOGLE_WORKSPACE_CLI_LOG_FILE ${lib.escapeShellArg gwsLogsDir}
    '';
  };
in
{
  nixpkgs.overlays = [ googleWorkspaceCliOverlay ];

  # gcloud keeps OAuth refresh/access tokens, active configurations, and account
  # metadata under CLOUDSDK_CONFIG. Persist that secret-bearing config directory,
  # but keep the command logs in ephemeral cache via a repaired symlink.
  system.activationScripts.prepareGoogleToolsState = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg gcloudConfigDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg gcloudLogsDir}
      rm -rf ${lib.escapeShellArg "${gcloudConfigDir}/logs"}
      ln -sfn ${lib.escapeShellArg gcloudLogsDir} ${lib.escapeShellArg "${gcloudConfigDir}/logs"}

      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg gwsConfigDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg gwsLogsDir}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${gcloudConfigDir} 0700 ${user} users -"
    "d ${gcloudLogsDir} 0700 ${user} users -"
    "L+ ${gcloudConfigDir}/logs - - - - ${gcloudLogsDir}"
    "d ${gwsConfigDir} 0700 ${user} users -"
    "d ${gwsLogsDir} 0700 ${user} users -"
  ];

  home-manager.users.${user}.home.packages = [
    googleCloudSdkPackage
    gwsPackage
  ];
}

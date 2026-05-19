{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  homeManagerUser = config.home-manager.users.${user};
  ghosttyConfigPath = homeManagerUser.xdg.configFile."ghostty/config".source;
  ghosttyConfigHome = pkgs.runCommand "ghostty-store-config-home" { } ''
    mkdir -p "$out/ghostty"
    ln -s ${ghosttyConfigPath} "$out/ghostty/config"
  '';
  ghosttyWrapper = pkgs.writeShellScript "ghostty-store-backed-config-wrapper" ''
    set -euo pipefail

    case "''${1-}" in
      +show-config|+edit-config)
        # These actions do not accept --config-file, so point only this helper
        # invocation at a store-backed XDG config tree. Normal terminal launches
        # below use CLI flags instead so shells spawned inside Ghostty inherit
        # the real user XDG environment.
        export XDG_CONFIG_HOME=${lib.escapeShellArg ghosttyConfigHome}
        exec ${pkgs.ghostty}/bin/ghostty "$@"
        ;;
      +validate-config)
        has_config_file=false
        for arg in "$@"; do
          case "$arg" in
            --config-file|--config-file=*)
              has_config_file=true
              ;;
          esac
        done
        if [ "$has_config_file" = false ]; then
          action=$1
          shift
          exec ${pkgs.ghostty}/bin/ghostty "$action" --config-file=${lib.escapeShellArg ghosttyConfigPath} "$@"
        fi
        exec ${pkgs.ghostty}/bin/ghostty "$@"
        ;;
      +*)
        exec ${pkgs.ghostty}/bin/ghostty "$@"
        ;;
      *)
        exec ${pkgs.ghostty}/bin/ghostty \
          --config-default-files=false \
          --config-file=${lib.escapeShellArg ghosttyConfigPath} \
          "$@"
        ;;
    esac
  '';

  # Keep Ghostty's Home Manager-rendered config store-backed. Ghostty supports
  # a CLI-only `config-default-files=false` switch plus repeatable
  # `config-file=...`, which lets regular terminal launches read the generated
  # config directly from /nix/store without touching $XDG_CONFIG_HOME. Patch the
  # desktop, D-Bus, and systemd unit metadata too; upstream files contain an
  # absolute Exec path to the original package, which would bypass this wrapper.
  ghosttyPackage = pkgs.symlinkJoin {
    name = "ghostty-store-backed-config";
    paths = [ pkgs.ghostty ];
    postBuild = ''
      rm -f "$out/bin/ghostty"
      install -D -m 0755 ${ghosttyWrapper} "$out/bin/ghostty"

      for file in \
        share/applications/com.mitchellh.ghostty.desktop \
        share/dbus-1/services/com.mitchellh.ghostty.service \
        share/systemd/user/app-com.mitchellh.ghostty.service
      do
        if [ -e "$out/$file" ]; then
          rm -f "$out/$file"
          substitute ${pkgs.ghostty}/$file "$out/$file" \
            --replace-fail ${pkgs.ghostty}/bin/ghostty "$out/bin/ghostty"
        fi
      done
    '';
  };
in
{
  home-manager.users.${user} = {
    programs.ghostty = {
      enable = true;
      package = ghosttyPackage;
      settings = {
        theme = "dark:3024 Night,light:3024 Day";
        font-family = "JuliaMono";
      };
    };

    xdg.configFile."ghostty/config".enable = false;
  };
}

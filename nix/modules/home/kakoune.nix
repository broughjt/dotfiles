{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;

  # A minimal XDG_CONFIG_HOME for kak containing only the colors directory.
  # Setting XDG_CONFIG_HOME in the wrapper points kak_config here so the
  # built-in colorscheme command finds custom themes without any overrides.
  # %val{runtime} is compiled-in and ignores KAKOUNE_RUNTIME, so this is the
  # only way to inject store-backed colorschemes via the normal lookup path.
  kakConfigHome = pkgs.runCommand "kakoune-config-home" { } ''
    mkdir -p "$out/kak/colors"
    cp ${../../../kak/colors/standard-dark.kak}  "$out/kak/colors/standard-dark.kak"
    cp ${../../../kak/colors/standard-light.kak} "$out/kak/colors/standard-light.kak"
  '';

  kakInitCommand = "source ${pkgs.kakoune}/share/kak/kakrc; source ${../../../kak/kakrc}";
  kakWrapper = pkgs.writeShellScript "kak-store-backed-config-wrapper" ''
    set -euo pipefail

    if [ -z "''${KAK_COLORSCHEME:-}" ]; then
      kak_colorscheme=standard-dark
      if gnome_color_scheme="$(${pkgs.glib}/bin/gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)"; then
        case "$gnome_color_scheme" in
          *prefer-dark*) kak_colorscheme=standard-dark ;;
          *) kak_colorscheme=standard-light ;;
        esac
      fi
      export KAK_COLORSCHEME="$kak_colorscheme"
    fi

    export XDG_CONFIG_HOME=${lib.escapeShellArg kakConfigHome}
    exec ${pkgs.kakoune}/bin/kak -n -E ${lib.escapeShellArg kakInitCommand} "$@"
  '';

  # Keep Kakoune's config store-backed. Kakoune has no direct --config flag,
  # so the wrapper skips default startup, explicitly loads the normal runtime
  # bootstrap, then loads the config from /nix/store. The runtime bootstrap
  # still provides Kakoune's standard autoload/colorscheme behavior.
  # Detect the GNOME light/dark preference before pointing XDG_CONFIG_HOME at
  # the store-only Kakoune config tree so Kakoune follows the same preference
  # Ghostty uses for its dark:/light: theme pair.
  kakounePackage = pkgs.symlinkJoin {
    name = "kakoune-store-backed-config";
    paths = [ pkgs.kakoune ];
    postBuild = ''
      rm -f "$out/bin/kak"
      install -D -m 0755 ${kakWrapper} "$out/bin/kak"
    '';
  };
in
{
  home-manager.users.${user} = {
    home.packages = [
      kakounePackage
      pkgs.kakoune-lsp
    ];
  };
}

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

  # Keep Kakoune's config store-backed. Kakoune has no direct --config flag,
  # so the wrapper skips default startup, explicitly loads the normal runtime
  # bootstrap, then loads the config from /nix/store. The runtime bootstrap
  # still provides Kakoune's standard autoload/colorscheme behavior.
  kakounePackage = pkgs.symlinkJoin {
    name = "kakoune-store-backed-config";
    paths = [ pkgs.kakoune ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/kak" \
        --set XDG_CONFIG_HOME ${kakConfigHome} \
        --add-flags "-n" \
        --add-flags ${lib.escapeShellArg "-E ${lib.escapeShellArg kakInitCommand}"}
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

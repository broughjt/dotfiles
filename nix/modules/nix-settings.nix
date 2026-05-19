{ nix-config }:

{
  config,
  lib,
  ...
}:

let
  homeDirectory = config.defaultDirectories.homeDirectory;
in
{
  nix = {
    channel.enable = false;
    settings = nix-config.nixSettings;
  };
  nixpkgs.config = nix-config.nixpkgsConfig;

  # With channels disabled and use-xdg-base-directories enabled, these legacy
  # home dotpaths should no longer be created or needed. Remove only known-safe
  # symlinks/empty channel directories; warn rather than deleting if anything
  # unexpected is present.
  system.activationScripts.removeLegacyNixHomeState = {
    deps = [ "users" ];
    text = ''
      remove_file_or_symlink() {
        path=$1
        if [ -L "$path" ] || [ -f "$path" ]; then
          rm -f "$path"
        elif [ -e "$path" ]; then
          echo "warning: not removing unexpected non-file legacy Nix path: $path" >&2
        fi
      }

      nix_defexpr=${lib.escapeShellArg homeDirectory}/.nix-defexpr
      if [ -L "$nix_defexpr" ]; then
        rm -f "$nix_defexpr"
      elif [ -d "$nix_defexpr" ]; then
        unexpected=$(
          find "$nix_defexpr" -mindepth 1 -maxdepth 1 \
            ! -name channels \
            ! -name channels_root \
            -printf '%f\n' \
            | sort \
            | tr '\n' ' '
        )
        if [ -z "$unexpected" ]; then
          rm -rf "$nix_defexpr"
        else
          echo "warning: not removing $nix_defexpr; unexpected entries: $unexpected" >&2
        fi
      elif [ -e "$nix_defexpr" ]; then
        echo "warning: not removing unexpected legacy Nix path: $nix_defexpr" >&2
      fi

      remove_file_or_symlink ${lib.escapeShellArg homeDirectory}/.nix-profile
      remove_file_or_symlink ${lib.escapeShellArg homeDirectory}/.nix-channels
    '';
  };
}

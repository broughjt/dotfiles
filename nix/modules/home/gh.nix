{
  config,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
  homeManagerUser = config.home-manager.users.${user};
  ghConfigSource = homeManagerUser.xdg.configFile."gh/config.yml".source;
  ghHostsDir = "${localDirectory}/hacks/gh/hosts";
  ghHostsFile = "${ghHostsDir}/hosts.yml";
  ghPackage = pkgs.writeShellScriptBin "gh" ''
    set -eu

    persistent_hosts_dir=${ghHostsDir}
    persistent_hosts_file="$persistent_hosts_dir/hosts.yml"
    runtime_parent="''${XDG_RUNTIME_DIR:-/tmp}"
    config_dir=$(mktemp -d "$runtime_parent/gh-config.XXXXXX")

    cleanup() {
      rm -rf "$config_dir"
    }
    trap cleanup EXIT

    mkdir -p "$persistent_hosts_dir"
    chmod 0700 "$persistent_hosts_dir"

    install -m 0600 ${ghConfigSource} "$config_dir/config.yml"
    if [ -e "$persistent_hosts_file" ]; then
      install -m 0600 "$persistent_hosts_file" "$config_dir/hosts.yml"
    else
      : > "$config_dir/hosts.yml"
      chmod 0600 "$config_dir/hosts.yml"
    fi

    export GH_CONFIG_DIR="$config_dir"
    set +e
    ${pkgs.gh}/bin/gh "$@"
    status=$?
    set -e

    if [ -e "$config_dir/hosts.yml" ]; then
      install -m 0600 "$config_dir/hosts.yml" "$persistent_hosts_file"
    fi

    exit "$status"
  '';
in
{
  home-manager.users.${user} = {
    programs.gh = {
      enable = true;
      package = ghPackage;
      settings.git_protocol = "ssh";
    };

    # Keep gh's declarative config recreated from the store by the wrapper above.
    # Mutable account metadata lives narrowly in ~/local/hacks/gh/hosts/hosts.yml,
    # while the actual auth token is stored through libsecret/GNOME keyring.
    xdg.configFile."gh/config.yml".enable = false;

    home.activation.migrateGhHostsToHack = ''
      old_xdg_hosts="${homeManagerUser.xdg.configHome}/gh/hosts.yml"
      old_hack_hosts="${localDirectory}/hacks/gh/config/hosts.yml"
      new_hosts="${ghHostsFile}"

      if [ ! -s "$new_hosts" ]; then
        for old_hosts in "$old_xdg_hosts" "$old_hack_hosts"; do
          if [ -s "$old_hosts" ]; then
            run mkdir -m 0700 -p "${ghHostsDir}"
            run install -m 0600 "$old_hosts" "$new_hosts"
            break
          fi
        done
      fi
    '';
  };
}

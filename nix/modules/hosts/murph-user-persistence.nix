{
  config,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
in
{
  systemd.tmpfiles.rules = [
    # Fish rewrites history via temporary files and rename, so persist a real
    # directory and point the normal history path at it with a symlink instead
    # of bind-mounting fish_history itself.
    "d ${localDirectory}/share/fish 0700 ${user} users -"
    "d ${localDirectory}/hacks 0755 ${user} users -"
    "d ${localDirectory}/hacks/fish 0700 ${user} users -"
    "d ${localDirectory}/hacks/fish/fish_history 0700 ${user} users -"
    "f ${localDirectory}/hacks/fish/fish_history/fish_history 0600 ${user} users -"
    "L+ ${localDirectory}/share/fish/fish_history - - - - ${localDirectory}/hacks/fish/fish_history/fish_history"

    # Keep SSH client state out of ~/.ssh. The private key is the only secret
    # persisted here; known_hosts is intentionally mutable but narrowly scoped.
    "d ${localDirectory}/secrets 0700 ${user} users -"
    "d ${localDirectory}/secrets/ssh 0700 ${user} users -"
    "d ${localDirectory}/hacks/ssh 0700 ${user} users -"
    "d ${localDirectory}/hacks/ssh/known_hosts 0700 ${user} users -"
    "f ${localDirectory}/hacks/ssh/known_hosts/known_hosts 0600 ${user} users -"
    "d ${localDirectory}/hacks/gh 0700 ${user} users -"
    "d ${localDirectory}/hacks/gh/hosts 0700 ${user} users -"
    "f ${localDirectory}/hacks/gh/hosts/hosts.yml 0600 ${user} users -"
    "d ${localDirectory}/hacks/tmux 0700 ${user} users -"
    "d ${localDirectory}/hacks/tmux/resurrect 0700 ${user} users -"
    "d ${localDirectory}/hacks/tmux/resurrect/resurrect 0700 ${user} users -"

    # direnv allow/deny records are explicit trust decisions. Persist the
    # decisions without persisting all of direnv's data directory.
    "d ${localDirectory}/share/direnv 0700 ${user} users -"
    "d ${localDirectory}/share/direnv/allow 0700 ${user} users -"
    "d ${localDirectory}/share/direnv/deny 0700 ${user} users -"

    # Emacs known-projects list. Backups and auto-saves are persisted at
    # their XDG state paths via environment.persistence below; other Emacs
    # state (eln-cache, auto-save-list, transient, custom, bookmarks) is
    # intentionally ephemeral under ~/local/{cache,state}/emacs.
    "d ${localDirectory}/hacks/emacs 0700 ${user} users -"
    "d ${localDirectory}/hacks/emacs/projects 0700 ${user} users -"
    "f ${localDirectory}/hacks/emacs/projects/projects.eld 0600 ${user} users - nil"

    # GnuPG: only durable subcomponents are persisted. GNUPGHOME itself is
    # ephemeral and only holds activation-managed symlinks plus throwaway
    # state (random_seed, locks, sockets, crls.d). pubring.kbx and
    # trustdb.gpg live in a persisted directory so gpg's temp+rename writes
    # do not get pinned by per-file impermanence binds. private-keys-v1.d
    # and openpgp-revocs.d are symlinked into the persisted secrets tree.
    "d ${localDirectory}/secrets/gnupg 0700 ${user} users -"
    "d ${localDirectory}/secrets/gnupg/private-keys-v1.d 0700 ${user} users -"
    "d ${localDirectory}/secrets/gnupg/openpgp-revocs.d 0700 ${user} users -"
    "d ${localDirectory}/state/gnupg 0700 ${user} users -"
    "d ${localDirectory}/share/gnupg 0700 ${user} users -"
    "L+ ${localDirectory}/share/gnupg/private-keys-v1.d - - - - ${localDirectory}/secrets/gnupg/private-keys-v1.d"
    "L+ ${localDirectory}/share/gnupg/openpgp-revocs.d - - - - ${localDirectory}/secrets/gnupg/openpgp-revocs.d"
  ];

  system.activationScripts.warnUnexpectedHackState = {
    deps = [ "persist-files" ];
    text = ''
      check_single_entry() {
        dir=$1
        expected=$2
        [ -d "$dir" ] || return 0

        unexpected=$(
          find "$dir" -mindepth 1 -maxdepth 1 -printf '%f\n' \
            | { grep -vxF "$expected" || true; } \
            | sort \
            | tr '\n' ' '
        )

        if [ -n "$unexpected" ]; then
          echo "warning: unexpected state in $dir; expected only '$expected', found: $unexpected" >&2
        fi
      }

      check_store_backed_gnupg_config() {
        path=$1
        [ -e "$path" ] || [ -L "$path" ] || return 0

        if [ -L "$path" ]; then
          target=$(readlink "$path" || true)
          case "$target" in
            /nix/store/*)
              rm -f "$path"
              return 0
              ;;
          esac
        fi

        echo "warning: unexpected mutable GnuPG config at $path; config should be store-backed" >&2
      }

      check_single_entry ${localDirectory}/hacks/fish/fish_history fish_history
      check_single_entry ${localDirectory}/hacks/ssh/known_hosts known_hosts
      check_single_entry ${localDirectory}/hacks/gh/hosts hosts.yml
      check_single_entry ${localDirectory}/hacks/tmux/resurrect resurrect
      check_single_entry ${localDirectory}/hacks/emacs/projects projects.eld
      check_single_entry ${localDirectory}/hacks/pi/settings settings.json
      check_single_entry ${localDirectory}/secrets/pi/auth auth.json
      check_single_entry ${localDirectory}/secrets/pi/mcp mcp.json
      check_store_backed_gnupg_config ${localDirectory}/share/gnupg/gpg.conf
      check_store_backed_gnupg_config ${localDirectory}/share/gnupg/gpg-agent.conf
    '';
  };

  environment.persistence."/persist".users.${user} = {
    directories = [
      "repositories"
      "scratch"
      "share"

      {
        directory = "local/hacks/pi/settings";
        mode = "0700";
      }
      {
        directory = "local/secrets/pi/auth";
        mode = "0700";
      }
      {
        directory = "local/secrets/pi/mcp";
        mode = "0700";
      }
      {
        directory = "local/secrets/pi/mcp-oauth";
        mode = "0700";
      }
      {
        directory = "local/state/pi/sessions";
        mode = "0700";
      }
      {
        directory = "local/state/pi/mcp";
        mode = "0700";
      }
      {
        directory = "local/hacks/fish/fish_history";
        mode = "0700";
      }
      {
        directory = "local/hacks/ssh/known_hosts";
        mode = "0700";
      }
      {
        directory = "local/hacks/gh/hosts";
        mode = "0700";
      }
      {
        directory = "local/hacks/tmux/resurrect";
        mode = "0700";
      }
      {
        directory = "local/hacks/emacs/projects";
        mode = "0700";
      }
      {
        directory = "local/state/emacs/backups";
        mode = "0700";
      }
      {
        directory = "local/state/emacs/auto-saves";
        mode = "0700";
      }
      {
        directory = "local/secrets/ssh";
        mode = "0700";
      }
      {
        directory = "local/share/direnv/allow";
        mode = "0700";
      }
      {
        directory = "local/share/direnv/deny";
        mode = "0700";
      }
      {
        directory = "local/secrets/gnupg";
        mode = "0700";
      }
      {
        directory = "local/state/gnupg";
        mode = "0700";
      }
      {
        directory = "local/share/keyrings";
        mode = "0700";
      }
      {
        directory = "local/config/mozilla/firefox";
        mode = "0700";
      }
      {
        directory = "local/config/discord";
        mode = "0700";
      }
      {
        directory = "local/config/Slack";
        mode = "0700";
      }
      {
        directory = "local/config/spotify";
        mode = "0700";
      }
      {
        directory = "local/secrets/claude-code/auth";
        mode = "0700";
      }
      {
        directory = "local/secrets/claude-code/credentials";
        mode = "0700";
      }
      {
        directory = "local/state/claude-code/history";
        mode = "0700";
      }
      {
        directory = "local/state/claude-code/projects";
        mode = "0700";
      }
      {
        directory = "local/state/claude-code/sessions";
        mode = "0700";
      }
    ];

    files = [ ];
  };
}

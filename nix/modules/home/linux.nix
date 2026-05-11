{ homeDirectories }:

{
  config,
  pkgs,
  ...
}:

{
  imports = [ homeDirectories ];

  config =
    let
      user = config.personal.userName;
      homeDirectory = config.defaultDirectories.homeDirectory;
      localDirectory = config.defaultDirectories.localDirectory;
      homeManagerUser = config.home-manager.users.${user};
      xdgEnvironment = {
        XDG_CACHE_HOME = "${localDirectory}/cache";
        XDG_CONFIG_HOME = "${localDirectory}/config";
        XDG_DATA_HOME = "${localDirectory}/share";
        XDG_STATE_HOME = "${localDirectory}/state";
      };
      userEnvironment = xdgEnvironment // {
        GIT_CONFIG_GLOBAL = "${homeManagerUser.xdg.configFile."git/config".source}";
      };
      tmuxConfigPath = homeManagerUser.xdg.configFile."tmux/tmux.conf".source;
      tmuxPackage = pkgs.writeShellScriptBin "tmux" ''
        exec ${pkgs.tmux}/bin/tmux -f ${tmuxConfigPath} "$@"
      '';
    in
    {
      systemd.services."user@1000" = {
        overrideStrategy = "asDropin";
        environment = userEnvironment;
      };

      systemd.services."home-manager-${user}".environment = userEnvironment;

      systemd.tmpfiles.rules = [
        "d ${localDirectory} 0755 ${user} users -"
        "d ${localDirectory}/config 0755 ${user} users -"
        "d ${localDirectory}/cache 0700 ${user} users -"
        "d ${localDirectory}/share 0755 ${user} users -"
        "d ${localDirectory}/state 0755 ${user} users -"
      ];

      programs.ssh.extraConfig = ''
        Match localuser ${user}
          AddKeysToAgent yes
          IdentityFile ${localDirectory}/secrets/ssh/id_ed25519
          UserKnownHostsFile ${localDirectory}/hacks/ssh/known_hosts/known_hosts
      '';

      home-manager.useGlobalPkgs = true;
      home-manager.users.${user} = {
        home.stateVersion = "25.05";
        programs.home-manager.enable = true;
        home.homeDirectory = homeDirectory;

        xdg = {
          enable = true;
          cacheHome = xdgEnvironment.XDG_CACHE_HOME;
          configHome = xdgEnvironment.XDG_CONFIG_HOME;
          dataHome = xdgEnvironment.XDG_DATA_HOME;
          stateHome = xdgEnvironment.XDG_STATE_HOME;
          userDirs = {
            enable = true;
            setSessionVariables = false;
            desktop = config.defaultDirectories.scratchDirectory;
            documents = "${config.defaultDirectories.shareDirectory}/documents";
            download = config.defaultDirectories.scratchDirectory;
            music = "${config.defaultDirectories.shareDirectory}/music";
            pictures = "${config.defaultDirectories.shareDirectory}/pictures";
            publicShare = config.defaultDirectories.shareDirectory;
            templates = null;
            videos = "${config.defaultDirectories.shareDirectory}/videos";
          };
        };

        home.packages = with pkgs; [
          direnv
          eza
          fd
          jq
          killall
          lldb
          ripgrep
        ];

        programs.fish = {
          enable = true;
          interactiveShellInit = "fish_vi_key_bindings";
          shellAliases.ls = "eza --group-directories-first";
        };

        programs.git = {
          enable = true;
          settings = {
            user = {
              name = config.personal.fullName;
              email = config.personal.email;
            };
            # "Are the worker threads going to unionize?"
            init.defaultBranch = "main";
          };
          signing.key = "1BA5F1335AB45105";
          signing.signByDefault = config.home-manager.users.${config.personal.userName}.programs.gpg.enable;
        };

        # Keep global Git config fully declarative. Home Manager still renders
        # the config into the Nix store, but Git reads it directly from there
        # instead of through a symlink at $XDG_CONFIG_HOME/git/config.
        xdg.configFile."git/config".enable = false;
        home.sessionVariables.GIT_CONFIG_GLOBAL = userEnvironment.GIT_CONFIG_GLOBAL;

        home.file."local/secrets/ssh/id_ed25519.pub" = {
          force = true;
          text = config.personal.sshPublicKey + "\n";
        };

        # Keep tmux config fully declarative. Home Manager still renders the
        # config into the Nix store, but the tmux command is wrapped with
        # `-f /nix/store/...-hm_tmuxtmux.conf` instead of using an XDG symlink.
        xdg.configFile."tmux/tmux.conf".enable = false;

        programs.tmux = {
          enable = true;
          package = tmuxPackage;
          sensibleOnTop = true;
          keyMode = "vi";
          customPaneNavigationAndResize = true;
          mouse = true;
          historyLimit = 50000;
          terminal = "tmux-256color";
          plugins = with pkgs.tmuxPlugins; [
            {
              plugin = yank;
              extraConfig = ''
                set -g @copy_command '${pkgs.wl-clipboard}/bin/wl-copy'
              '';
            }
            {
              plugin = resurrect;
              extraConfig = ''
                set -g @resurrect-capture-pane-contents 'on'
                set -g @resurrect-dir '${config.defaultDirectories.localDirectory}/hacks/tmux/resurrect/resurrect'
                set -g @resurrect-strategy-nvim 'session'
              '';
            }
            {
              plugin = continuum;
              extraConfig = ''
                set -g @continuum-restore 'on'
                set -g @continuum-save-interval '15'
              '';
            }
          ];
        };
      };
    };
}

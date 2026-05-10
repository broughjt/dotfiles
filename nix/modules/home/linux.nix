{ homeDirectories }:

{ config, pkgs, ... }:

{
  imports = [ homeDirectories ];

  config =
    let
      user = config.personal.userName;
      homeDirectory = config.defaultDirectories.homeDirectory;
      localDirectory = config.defaultDirectories.localDirectory;
    in
    {
      environment.sessionVariables = {
        XDG_CACHE_HOME = "${localDirectory}/cache";
        XDG_CONFIG_HOME = "${localDirectory}/config";
        XDG_DATA_HOME = "${localDirectory}/share";
        XDG_STATE_HOME = "${localDirectory}/state";
      };

      systemd.tmpfiles.rules = [
        "d ${localDirectory} 0755 ${user} users -"
        "d ${localDirectory}/config 0755 ${user} users -"
        "d ${localDirectory}/cache 0700 ${user} users -"
        "d ${localDirectory}/share 0755 ${user} users -"
        "d ${localDirectory}/state 0755 ${user} users -"
      ];

      home-manager.useGlobalPkgs = true;
      home-manager.users.${user} = {
        home.stateVersion = "25.05";
        programs.home-manager.enable = true;
        home.homeDirectory = homeDirectory;

        xdg = {
          enable = true;
          cacheHome = "${localDirectory}/cache";
          configHome = "${localDirectory}/config";
          dataHome = "${localDirectory}/share";
          stateHome = "${localDirectory}/state";
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

        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          matchBlocks = {
            "*" = {
              identityFile = "~/.ssh/id_ed25519";
              addKeysToAgent = "yes";
            };
          };
        };

        programs.tmux = {
          enable = true;
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

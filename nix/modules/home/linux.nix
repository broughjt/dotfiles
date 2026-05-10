{ homeDirectories }:

{
  config,
  lib,
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
      # Adapt Home Manager's programs.git rendering logic so Git can read the
      # generated config directly from /nix/store via GIT_CONFIG_GLOBAL instead
      # of through an XDG config symlink. Keep this in sync with:
      # https://github.com/nix-community/home-manager/blob/e4419d3123b780d5f4c0bceeace450424387638c/modules/programs/git.nix#L346-L353
      gitConfigPath =
        let
          gitConfig = config.home-manager.users.${user}.programs.git;
          settingsFragments = if builtins.isList gitConfig.settings then gitConfig.settings else [ ];
          renderedIniFragments = lib.filter (text: lib.match "[[:space:]]*" text == null) (
            [ (lib.generators.toGitINI gitConfig.iniContent) ] ++ map lib.generators.toGitINI settingsFragments
          );
        in
        pkgs.writeText "hm_gitconfig" (lib.concatStringsSep "\n" renderedIniFragments);
      # Adapt Home Manager's programs.tmux rendering logic so tmux can read the
      # generated config directly from /nix/store via TMUX_CONF instead of
      # through an XDG config symlink. Keep this in sync with:
      # https://github.com/nix-community/home-manager/blob/e4419d3123b780d5f4c0bceeace450424387638c/modules/programs/tmux.nix
      tmuxConfigPath =
        let
          tmuxConfig = config.home-manager.users.${user}.programs.tmux;
          boolToStr = value: if value then "on" else "off";
          pluginName = p: if lib.types.package.check p then p.pname else p.plugin.pname;
          baseConfig = ''
            ${lib.optionalString tmuxConfig.sensibleOnTop ''
              # ============================================= #
              # Start with defaults from the Sensible plugin  #
              # --------------------------------------------- #
              run-shell ${pkgs.tmuxPlugins.sensible.rtp}
              # ============================================= #
            ''}
            set  -g default-terminal "${tmuxConfig.terminal}"
            set  -g base-index      ${toString tmuxConfig.baseIndex}
            setw -g pane-base-index ${toString tmuxConfig.baseIndex}
            ${lib.optionalString (tmuxConfig.shell != null) ''
              # We need to set default-shell before calling new-session
              set  -g default-shell "${tmuxConfig.shell}"
            ''}
            ${lib.optionalString tmuxConfig.newSession ''
              # Use -A to make new-session idempotent: attach if session "0" exists,
              # otherwise create it. This prevents duplicate sessions when multiple
              # configs (e.g., system and user) both enable newSession.
              new-session -A -s 0''}

            ${lib.optionalString tmuxConfig.reverseSplit ''
              bind -N "Split the pane into two, left and right" v split-window -h
              bind -N "Split the pane into two, top and bottom" s split-window -v
            ''}

            set -g status-keys ${tmuxConfig.keyMode}
            set -g mode-keys   ${tmuxConfig.keyMode}

            ${lib.optionalString (tmuxConfig.keyMode == "vi" && tmuxConfig.customPaneNavigationAndResize) ''
              bind -N "Select pane to the left of the active pane" h select-pane -L
              bind -N "Select pane below the active pane" j select-pane -D
              bind -N "Select pane above the active pane" k select-pane -U
              bind -N "Select pane to the right of the active pane" l select-pane -R

              bind -r -N "Resize the pane left by ${toString tmuxConfig.resizeAmount}" \
                H resize-pane -L ${toString tmuxConfig.resizeAmount}
              bind -r -N "Resize the pane down by ${toString tmuxConfig.resizeAmount}" \
                J resize-pane -D ${toString tmuxConfig.resizeAmount}
              bind -r -N "Resize the pane up by ${toString tmuxConfig.resizeAmount}" \
                K resize-pane -U ${toString tmuxConfig.resizeAmount}
              bind -r -N "Resize the pane right by ${toString tmuxConfig.resizeAmount}" \
                L resize-pane -R ${toString tmuxConfig.resizeAmount}
            ''}

            ${
              let
                defaultPrefix = "C-b";
                prefix = if tmuxConfig.prefix != null then tmuxConfig.prefix else "C-${tmuxConfig.shortcut}";
              in
              lib.optionalString (prefix != defaultPrefix) ''
                # rebind main key: ${prefix}
                unbind ${defaultPrefix}
                set -g prefix ${prefix}
                bind -N "Send the prefix key through to the application" \
                  ${prefix} send-prefix
              ''
            }

            ${lib.optionalString tmuxConfig.disableConfirmationPrompt ''
              bind-key -N "Kill the current window" & kill-window
              bind-key -N "Kill the current pane" x kill-pane
            ''}

            set  -g mouse             ${boolToStr tmuxConfig.mouse}
            set  -g focus-events      ${boolToStr tmuxConfig.focusEvents}
            setw -g aggressive-resize ${boolToStr tmuxConfig.aggressiveResize}
            setw -g clock-mode-style  ${if tmuxConfig.clock24 then "24" else "12"}
            set  -s escape-time       ${toString tmuxConfig.escapeTime}
            set  -g history-limit     ${toString tmuxConfig.historyLimit}
          '';
          pluginsConfig = lib.optionalString (tmuxConfig.plugins != [ ]) ''
            # ============================================= #
            # Load plugins with Home Manager                #
            # --------------------------------------------- #

            ${lib.concatMapStringsSep "\n\n" (p: ''
              # ${pluginName p}
              # ---------------------
              ${p.extraConfig or ""}
              run-shell ${if lib.types.package.check p then p.rtp else p.plugin.rtp}
            '') tmuxConfig.plugins}
            # ============================================= #
          '';
        in
        pkgs.writeText "hm_tmuxtmux.conf" ''
          ${baseConfig}
          ${tmuxConfig.extraConfig}
          ${pluginsConfig}
        '';
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

        # Keep global Git config fully declarative. Home Manager still renders
        # the config into the Nix store, but Git reads it directly from there
        # instead of through a symlink at $XDG_CONFIG_HOME/git/config.
        xdg.configFile."git/config".enable = false;
        home.sessionVariables.GIT_CONFIG_GLOBAL = "${gitConfigPath}";
        systemd.user.sessionVariables.GIT_CONFIG_GLOBAL = "${gitConfigPath}";

        # Keep tmux config fully declarative and avoid an XDG config symlink.
        # Home Manager renders the config into the Nix store; TMUX_CONF points
        # tmux at that store path directly.
        xdg.configFile."tmux/tmux.conf".enable = false;
        home.sessionVariables.TMUX_CONF = "${tmuxConfigPath}";
        systemd.user.sessionVariables.TMUX_CONF = "${tmuxConfigPath}";

        home.file."local/secrets/ssh/id_ed25519.pub" = {
          force = true;
          text = config.personal.sshPublicKey + "\n";
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

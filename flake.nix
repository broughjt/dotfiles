{
  description = "Are these your configuration files, Larry?";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, emacs-overlay }:
    let
      fullName = "Jackson Brough";
      userName = "jackson";
      email = "jacksontbrough@gmail.com";
      sharedHomeConfiguration = { lib, config, pkgs, ... }:
        let
          emacs = (pkgs.emacsWithPackagesFromUsePackage {
            config = ./emacs.el;
            defaultInitFile = true;
            package = pkgs.emacs-unstable-pgtk;
            extraEmacsPackages = epkgs: [ epkgs.treesit-grammars.with-all-grammars ];
            alwaysEnsure = true;
          });
        in
        {
          # TODO: Paths?

          options.repositoriesDirectory = lib.mkOption {
            type = lib.types.str;
            default = "${config.homeDirectory}/repositories";
          };

          options.sharedDirectory = lib.mkOption {
            type = lib.types.str;
            default = "${config.homeDirectory}/shared";
          };

          options.localDirectory = lib.mkOption {
            type = lib.types.str;
            default = "${config.homeDirectory}/local";
          };

          options.scratchDirectory = lib.mkOption {
            type = lib.types.str;
            default = "${config.homeDirectory}/scratch";
          };

          config = {
            home.username = userName;
            home.stateVersion = "23.05";
            home.packages = with pkgs; [
              exa
              ripgrep

              direnv
              gopass

              jetbrains-mono
            ];
            programs.home-manager.enable = true;

            xdg.enable = true;
            xdg.cacheHome = "${config.homeDirectory}/.cache";
            xdg.configHome = "${config.homeDirectory}/.config";
            xdg.dataHome = "${config.homeDirectory}/.local/share";
            xdg.stateHome = "${config.homeDirectory}/.local/state";

            programs.fish = {
              enable = true;
              interactiveShellInit = ''
                fish_vi_key_bindings
                alias ls='exa --group-directories-first'
              '';
            };

            programs.git = {
              enable = true;
              userEmail = email;
              signing.key = "1BA5F1335AB45105";
              signing.signByDefault = true;
              # "Are the worker threads going to unionize?"
              extraConfig = { init.defaultBranch = "main"; };
            };

            programs.gh.enable = true;

            programs.ssh.enable = true;
            services.ssh-agent.enable = true;

            programs.gpg = {
              enable = true;
              homedir = "${config.xdg.dataHome}/gnupg";
            };
            services.gpg-agent = {
              enable = true;
            };

            xdg.configFile.gopass = {
              target = "gopass/config";
              text = ''
                [mounts]
                    path = ${config.repositoriesDirectory}/passwords
                [recipients]
                    hash = c9903be2bdd11ffec04509345292bfa567e6b28e7e6aa866933254c5d1344326
              '';
            };

            programs.emacs = {
              enable = true;
              package = emacs;
            };
            services.emacs = {
              enable = true;
              package = emacs;
              defaultEditor = true;
            };
          };
        };
      darwinHomeConfiguration = { config, pkgs, ... }: {
        imports = [ sharedHomeConfiguration ];

        config = {
          home.homeDirectory = "/Users/${userName}";
        };
      };
      linuxHomeConfiguration = { config, pkgs, ... }:
        # https://nixos.wiki/wiki/Slack
        # https://wiki.archlinux.org/title/wayland
        # TODO: Screen sharing
        let
          slack = pkgs.slack.overrideAttrs (previous: {
            installPhase = previous.installPhase + ''
              rm $out/bin/slack

              makeWrapper $out/lib/slack/slack $out/bin/slack \
                --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
                --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.xdg-utils]} \
                --add-flags "--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-webrtc-pipewire-capturer"
            '';
          });
        in
        {
          imports = [ sharedHomeConfiguration ];

          config = {
            home.homeDirectory = "/home/${userName}";
            home.packages = with pkgs; [
              killall
              lldb

              pinentry-gnome
              source-sans
              source-serif

              gnome.dconf-editor
              gnomeExtensions.pop-shell
              whitesur-gtk-theme
              whitesur-icon-theme

              # TODO: zoom
              slack
              spotify
              playerctl
            ];

            xdg.userDirs = {
              createDirectories = true;
              documents = config.scratchDirectory;
              download = config.scratchDirectory;
              music = "${config.sharedDirectory}/music";
              pictures = "${config.sharedDirectory}/pictures";
              publicShare = config.scratchDirectory;
              templates = config.scratchDirectory;
              videos = "${config.sharedDirectory}/videos";
            };

            fonts.fontconfig.enable = true;

            services.gpg-agent.pinentryFlavor = "gnome3";

            # https://the-empire.systems/nixos-gnome-settings-and-keyboard-shortcuts
            # https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/
            # TODO: playerctl
            dconf.settings = {
              "org/gnome/shell" = {
                disable-user-extensions = false;
                disabled-extensions = "disabled";
                enabled-extensions = [
                  "pop-shell@system76.com"
                ];
              };
              "org/gnome/shell/extensions/pop-shell" = {
                tile-by-default = true;
              };
              "org/gnome/desktop/wm/keybindings" = {
                close = [ "<Super>q" ];
                minimize = [ "<Super>comma" ];
                toggle-maximized = [ "<Super>m" ];
                switch-to-workspace-1 = [ "<Super>1" ];
                switch-to-workspace-2 = [ "<Super>2" ];
                switch-to-workspace-3 = [ "<Super>3" ];
                switch-to-workspace-4 = [ "<Super>4" ];
                switch-to-workspace-5 = [ "<Super>5" ];
                switch-to-workspace-6 = [ "<Super>6" ];
                switch-to-workspace-7 = [ "<Super>7" ];
                switch-to-workspace-8 = [ "<Super>8" ];
                switch-to-workspace-9 = [ "<Super>9" ];
                move-to-workspace-1 = [ "<Super><Shift>1" ];
                move-to-workspace-2 = [ "<Super><Shift>2" ];
                move-to-workspace-3 = [ "<Super><Shift>3" ];
                move-to-workspace-4 = [ "<Super><Shift>4" ];
                move-to-workspace-5 = [ "<Super><Shift>5" ];
                move-to-workspace-6 = [ "<Super><Shift>6" ];
                move-to-workspace-7 = [ "<Super><Shift>7" ];
                move-to-workspace-8 = [ "<Super><Shift>8" ];
                move-to-workspace-9 = [ "<Super><Shift>9" ];
              };
              "org/gnome/shell/keybindings" = {
                toggle-message-tray = [ ];
                focus-active-notification = [ ];
                toggle-overview = [ ];
                switch-to-application-1 = [ ];
                switch-to-application-2 = [ ];
                switch-to-application-3 = [ ];
                switch-to-application-4 = [ ];
                switch-to-application-5 = [ ];
                switch-to-application-6 = [ ];
                switch-to-application-7 = [ ];
                switch-to-application-8 = [ ];
                switch-to-application-9 = [ ];
              };
              "org/gnome/mutter/keybindings" = {
                switch-monitor = [ ];
              };
              "org/gnome/settings-daemon/plugins/media-keys" = {
                rotate-video-lock-static = [ ];
                screenreader = [ ];
                custom-keybindings = [
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/"
                ];
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
                name = "Terminal";
                command = "kitty";
                binding = "<Super>t";
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
                name = "Browser";
                command = "firefox";
                binding = "<Super>b";
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
                name = "Emacs";
                command = "emacsclient -c";
                binding = "<Super>e";
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
                name = "Spotify";
                command = "spotify";
                binding = "<Super>s";
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
                name = "Next";
                command = "playerctl next";
                binding = "<Super>n";
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
                name = "Previous";
                command = "playerctl previous";
                binding = "<Super>p";
              };
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6" = {
                name = "Play";
                command = "playerctl play-pause";
                binding = "<Super>i";
              };
              "org/gnome/desktop/wm/preferences" = {
                theme = "WhiteSur";
                num-workspaces = 9;
              };
              "org/gnome/desktop/interface" = {
                clock-format = "12h";
                color-scheme = "prefer-dark";
                enable-hot-corners = false;
                # TODO
                # font-antialiasing = "grayscale";
                # font-hinting = "slight";
                gtk-theme = "WhiteSur";
                icon-theme = "WhiteSur";
                # toolkit-accessibility = true;
              };
              "org/gnome/desktop/background" = {
                picture-uri = "file://${config.xdg.userDirs.pictures}/deep-field.png";
                picture-uri-dark = "file://${config.xdg.userDirs.pictures}/deep-field.png";
              };
            };

            programs.kitty = {
              enable = true;
              font = { name = "JetBrains Mono"; size = 12; };
            };

            programs.firefox = {
              enable = true;
              enableGnomeExtensions = false;
            };

            services.emacs.startWithUserSession = "graphical";
          };
        };
    in
    {
      # TODO: config files directly in the nix store
      # TODO: remove default userDirs
      # TODO: impermanence
      # TODO: itnotify on /home/jackson
      # TODO: bluetooth
      # TODO: screen sharing
      # TODO: macOS decorations
      # TODO: racket config pkgs devShell thing
      # TODO: fingerprint
      # TODO: beets
      # TODO: https://github.com/nix-community/naersk
      # TODO: https://jmgilman.github.io/std-book/overview.html
      # TODO: https://www.oilshell.org/cross-ref.html?tag=YSH#YSH
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixpkgs-fmt;
      nixosConfigurations.murph = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ config, pkgs, ... }:

            {
              imports = [ ./hardware-configuration.nix ];

              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = true;
              boot.initrd.secrets = { "/crypto_keyfile.bin" = null; };
              # See https://download.nvidia.com/XFree86/Linux-x86_64/460.73.01/README/powermanagement.html
              # Known Issues and Workarounds
              boot.kernelParams = [ "mem_sleep_default=deep" ];

              networking.hostName = "murph";
              networking.networkmanager.enable = true;

              powerManagement.enable = true;

              # TODO: What is this needed for?
              security.polkit.enable = true;

              security.rtkit.enable = true;
              services.pipewire = {
                enable = true;
                alsa.enable = true;
                alsa.support32Bit = true;
                pulse.enable = true;
              };
              hardware.pulseaudio.enable = false;
              hardware.bluetooth.enable = true;
              services.blueman.enable = true;
              # TODO: Magical bluetooth incantations
              # environment.etc = {
              # "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
              # bluez_monitor.properties = {
              # ["bluez5.enable-sbc-xq"] = true,
              # ["bluez5.enable-msbc"] = true,
              # ["bluez5.enable-hw-volume"] = true,
              # ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
              # }
              # '';
              # };

              services.xserver = {
                enable = true;
                displayManager.gdm.enable = true;
                displayManager.gdm.wayland = true;
                desktopManager.gnome.enable = true;
                videoDrivers = [ "nvidia" ];
              };
              environment.gnome.excludePackages = (with pkgs; [
                gnome-photos
                gnome-tour
              ]) ++ (with pkgs.gnome; [
                cheese
                atomix
                epiphany
                evince
                geary
                gedit # @Conman
                gnome-characters
                gnome-music
                hitori
                iagno
                tali
                totem
                gnome-calculator
                gnome-calendar
                gnome-clocks
                gnome-contacts
                gnome-maps
                gnome-weather
                # gnome-disk-image-mounter
                # gnome-disks
                # gnome-extensions
                # gnome-extensions-app
                # gnome-logs
                # gnome-system-monitor
                simple-scan
              ]) ++ (with pkgs.gnome.apps; [
                # TODO: Figure how to remove these
                # gnome-connections
                # gnome-help
                # gnome-text-editor
                # gnome-thumbnail-font
              ]);
              hardware.opengl = {
                enable = true;
                driSupport = true;
                driSupport32Bit = true;
              };
              hardware.nvidia = {
                modesetting.enable = true;
                powerManagement.enable = true;
              };

              time.timeZone = "America/Denver";

              i18n.defaultLocale = "en_US.UTF-8";
              i18n.extraLocaleSettings = {
                LC_ADDRESS = "en_US.UTF-8";
                LC_IDENTIFICATION = "en_US.UTF-8";
                LC_MEASUREMENT = "en_US.UTF-8";
                LC_MONETARY = "en_US.UTF-8";
                LC_NAME = "en_US.UTF-8";
                LC_NUMERIC = "en_US.UTF-8";
                LC_PAPER = "en_US.UTF-8";
                LC_TELEPHONE = "en_US.UTF-8";
                LC_TIME = "en_US.UTF-8";
              };

              # Make Nix can flakes
              nix.package = pkgs.nixFlakes;
              nix.extraOptions = "experimental-features = nix-command flakes";
              nix.settings.trusted-users = [ "root" "jackson" ];

              nixpkgs.config.allowUnfree = true;

              environment.systemPackages = with pkgs; [
                curl
                # Prevent a world of pain where nix 2.4 has you fetching rocks for
                # a long time until you finally discover that it wanted git but
                # refused to tell you.
                git
                neovim
              ];

              programs.fish = {
                enable = true;
              };

              services.openssh = {
                enable = true;
                settings = {
                  PermitRootLogin = "no";
                  # TODO: Change these both to false but first understand how that would work from laptop to laptop
                  PasswordAuthentication = true;
                  KbdInteractiveAuthentication = true;
                };
              };

              system.stateVersion = "23.05";

              users.users.jackson = {
                isNormalUser = true;
                description = "Jackson Brough";
                extraGroups = [ "networkmanager" "wheel" "video" ];
                shell = pkgs.fish;
              };
            })
        ];
      };
      darwinConfigurations.kenobi = nix-darwin.lib.darwinSystem {
        modules = [
          ({ pkgs, ... }: {
            nixpkgs.hostPlatform = "x86_64-darwin";

            services.nix-daemon.enable = true;
            nix.settings.experimental-features = "nix-command flakes";

            environment.systemPackages = with pkgs; [ neovim ];

            programs.zsh.enable = true;

            system.configurationRevision = self.rev or self.dirtyRev or null;
            system.stateVersion = 4;

            users.users.${userName} = {
              home = "/Users/${userName}";
            };
          })
        ];
      };
      homeConfigurations."${userName}@kenobi" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-darwin;
        modules = [ darwinHomeConfiguration ];
      };
      homeConfigurations."${userName}@murph" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ linuxHomeConfiguration ];
      };
      templates.rust = {
        path = ./templates/rust;
        description = "Rust template";
      };
    };
}

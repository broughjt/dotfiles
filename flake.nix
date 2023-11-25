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

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixcasks.url = "github:jacekszymanski/nixcasks";
    nixcasks.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, nixcasks, emacs-overlay, agenix }:
    rec {
      nixosModules = rec {
        personal = { lib, ... }:
        
          {
            options.personal = lib.mkOption {
              type = lib.types.attrs;
              default = {
                userName = "jackson";
                fullName = "Jackson Brough";
                email = "jacksontbrough@gmail.com";
                devices = {
                  kenobi = {
                    ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBndIK51b/o6aSjuTdoa8emnpCRg0s5y68oXAFR66D4/ jacksontbrough@gmail.com";
                    syncthing = "7MDSHYK-QQSLKTX-LDA4VKP-EJASTEQ-V5JUGRT-ZRCNC7K-BFK6KQR-GAZ4JQV";
                  };
                  share1 = {
                    ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFpnGMEUElcwgnuHpBXQa4xotZrRdT6VC/7b9n5TykXZ root@share1";
                    syncthing = "CQ6ZTVZ-PWRWMW2-2BTFJ7V-XSMIHHU-VS4JIPD-HI3ALDJ-FH6HW5L-Z3WDIAX";
                    hostName = "share1.tail662f8.ts.net";
                  };
                  jackson-broughs-iphone = {
                    syncthing = "64BJT3J-XFGZYTG-TMJXAS5-4XACLPE-JUF6XHS-5G4DFYW-2QVAC4T-LLRKUAL";
                  };
                };
              };
            };
          };
        defaultDirectories = { config, lib, ... }:
        
          {
            options.defaultDirectories = {
              repositoriesDirectory = lib.mkOption { type = lib.types.str; default = "${config.home.homeDirectory}/repositories"; };
              localDirectory = lib.mkOption { type = lib.types.str; default = "${config.home.homeDirectory}/local"; };
              scratchDirectory = lib.mkOption { type = lib.types.str; default = "${config.home.homeDirectory}/scratch"; };
              shareDirectory = lib.mkOption { type = lib.types.str; default = "${config.home.homeDirectory}/share"; };
            };
          };
        package-manager = { pkgs, ... }:
        
          {
            nix.package = pkgs.nixFlakes;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
        
            nixpkgs.config.allowUnfree = true;
          };
        system = { config, pkgs, ... }:
        
          {
            imports = [ agenix.nixosModules.default package-manager personal ];
        
            nix.settings.trusted-users = [ "root" config.personal.userName ];
        
            environment.systemPackages = with pkgs; [ curl git neovim ];
            environment.shells = with pkgs; [ bashInteractive zsh fish ];
        
            programs.fish.enable = true;
        
            users.users.${config.personal.userName}.shell = pkgs.fish;
          };
        linuxSystem = { config, pkgs, ... }:
        
          {
            imports = [ system ];
        
            system.stateVersion = "23.05";
        
            hardware.enableRedistributableFirmware = true;
        
            users.users.${config.personal.userName} = {
              home = "/home/${config.personal.userName}";
              extraGroups = [ "docker" "wheel" ];
              isNormalUser = true;
            };
        
            virtualisation.docker.enable = true;
        
            services.openssh.enable = true;
          };
        darwinSystem = { config, pkgs, ... }:
        
          {
            imports = [ system ];
        
            config = {
              services.nix-daemon.enable = true;
              system.configurationRevision = self.rev or self.dirtyRev or null;
              system.stateVersion = 4;
        
              users.users.${config.personal.userName}.home = "/Users/${config.personal.userName}";
        
              homebrew.enable = true;
              homebrew.casks = [
                "discord"
                "docker"
                "logseq"
                "slack"
                "spotify"
                "zoom"
              ];
        
              services.tailscale.enable = true;
            };
          };
        raspberryPi4 = ({config, modulesPath, lib, pkgs, ... }:
        
          {
            imports = [
              linuxSystem
            ];
        
            boot = {
              kernelParams = [ "console=ttyS1,115200n8" ];
              initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
              loader = {
                grub.enable = false;
                generic-extlinux-compatible.enable = true;
              };
            };
        
            fileSystems = {
              "/" = {
                device = "/dev/disk/by-label/NIXOS_SD";
                fsType = "ext4";
                options = [ "noatime" ];
              };
            };
        
            networking.wireless = {
              enable = true;
              interfaces = [ "wlan0" ];
            };
        
            powerManagement.enable = true;
            powerManagement.cpuFreqGovernor = "ondemand";
          });
        share = ({ config, pkgs, ... }:
          
          {
            imports = [
              tailscale-autoconnect
            ];
            
            environment.systemPackages = [ pkgs.tailscale ];
            
            services.tailscaleAutoConnect = {
              enable = true;
              loginServer = "https://login.tailscale.com";
            };
        
            services.syncthing = {
              enable = true;
              openDefaultPorts = true;
              user = config.personal.userName;
              dataDir = config.users.users.${config.personal.userName}.home;
              guiAddress = "0.0.0.0:8384";
              overrideDevices = true;
              overrideFolders = true;
              settings = {
                devices = {
                  "kenobi".id = config.personal.devices.kenobi.syncthing;
                  "jackson-broughs-iphone".id = config.personal.devices.jackson-broughs-iphone.syncthing;
                };
                folders = {
                  "share" = {
                    path = config.services.syncthing.dataDir + "/share";
                    devices = [ "kenobi" "jackson-broughs-iphone" ];
                  };
                };
              };
            };
            users.users.${config.personal.userName}.extraGroups = [ "syncthing" "nginx" ];
        
            # age.secrets.webdav-user1 = {
              # file = ./secrets/webdav-user1.age;
              # mode = "770";
              # owner = "nginx";
              # group = "nginx";
            # };
            services.nginx = {
              enable = true;
              user = config.personal.userName;
              group = "nginx"
              additionalModules = with pkgs.nginxModules; [ dav ];
              # TODO: This should be a configuration option, not hardcoded to share1
              virtualHosts.${config.personal.devices.share1.hostName} = {
                forceSSL = true;
                # Same here
                root = config.services.syncthing.dataDir + "/share";
                # TODO: Same here
                basicAuth.foo = "bar";
                locations."/".extraConfig = ''
                  dav_methods PUT DELETE MKCOL COPY MOVE;
                  dav_ext_methods PROPFIND OPTIONS;
                  dav_access user:rw group:rw all:rw;
        
                  client_max_body_size 0;
                  create_full_put_path on;
        
                  if ($request_method = 'OPTIONS') {
                      add_header 'Access-Control-Allow-Origin' '*';
                      add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
                      add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
                      add_header 'Access-Control-Max-Age' 1728000;
                      add_header 'Content-Type' 'text/plain; charset=utf-8';
                      add_header 'Content-Length' 0;
                      return 204;
                  }
                  if ($request_method = 'POST') {
                      add_header 'Access-Control-Allow-Origin' '*' always;
                      add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
                      add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
                      add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
                  }
                  if ($request_method = 'GET') {
                      add_header 'Access-Control-Allow-Origin' '*' always;
                      add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
                      add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
                      add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
                  }
                '';
              };
            };
            # security.acme = {
              # acceptTerms = true;
              # defaults.email = config.personal.email;
            # };
          });
        share1 = ({ config, pkgs, ... }:
        
          {
            imports = [
              raspberryPi4
              wireless
              share
            ];
        
            networking.hostName = "share1";
        
            users.users = {
              ${config.personal.userName}.openssh.authorizedKeys.keys = [ config.personal.devices.kenobi.ssh ];
              root.openssh.authorizedKeys.keys = [ config.personal.devices.kenobi.ssh ];
            };
        
            age.secrets.share1-auth-key1.file = ./secrets/share1-auth-key1.age;
            services.tailscaleAutoConnect.authKeyFile = config.age.secrets.share1-auth-key1.path;
            services.nginx.virtualHosts.${config.personal.devices.share1.hostName} = let
              prefix = "/etc/ssl/certs/";
            in
              {
                sslCertificate = prefix + "share1.tail662f8.ts.net.crt";
                sslCertificateKey = prefix + "share1.tail662f8.ts.net.key";
              };
        
            nixpkgs.hostPlatform = "aarch64-linux";
          });
        home = { lib, config, pkgs, ... }:
        
          {
            imports = [ personal defaultDirectories ];
        
            nixpkgs.overlays = [ agenix.overlays.default ];
        
            home.username = config.personal.userName;
            home.stateVersion = "23.05";
            home.packages = with pkgs; [
              pkgs.agenix
              direnv
              eza
              gopass
              jq
              lldb
              ripgrep
            ];
            programs.home-manager.enable = true;
          
            xdg.enable = true;
            xdg.cacheHome = "${config.home.homeDirectory}/.cache";
            xdg.configHome = "${config.home.homeDirectory}/.config";
            xdg.dataHome = "${config.home.homeDirectory}/.local/share";
            xdg.stateHome = "${config.home.homeDirectory}/.local/state";
          
            programs.fish = {
              enable = true;
              interactiveShellInit = "fish_vi_key_bindings";
              shellAliases.ls = "exa --group-directories-first";
            };
          
            programs.git = {
              enable = true;
              userName = config.personal.fullName;
              userEmail = config.personal.email;
              signing.key = "1BA5F1335AB45105";
              signing.signByDefault = true;
              # "Are the worker threads going to unionize?"
              extraConfig.init.defaultBranch = "main";
            };
          
            programs.gh = {
              enable = true;
              settings.git_protocol = "ssh";
            };
          
            programs.ssh.enable = true;
          
            programs.gpg = {
              enable = true;
              homedir = "${config.xdg.dataHome}/gnupg";
            };
          
            xdg.configFile.gopass = {
              target = "gopass/config";
              text = ''
                [mounts]
                    path = ${config.defaultDirectories.repositoriesDirectory}/passwords
                [recipients]
                    hash = c9903be2bdd11ffec04509345292bfa567e6b28e7e6aa866933254c5d1344326
              '';
            };
          };
        darwinHome = { config, pkgs, nixcasks, lib, ... }:
        
        {
          imports = [ home emacsConfiguration defaultSettings ];
           
          nixpkgs.overlays = [ (final: prev: { inherit nixcasks; }) ];
        
          home.homeDirectory = "/Users/${config.personal.userName}";
          home.packages = with pkgs; [
            # Seems to be broken
            # nixcasks.slack
            # Seems to be broken
            # nixcasks.docker
            jetbrains-mono
            (pkgs.texlive.combine {
              inherit (pkgs.texlive) scheme-basic
                dvisvgm dvipng
                wrapfig amsmath ulem hyperref capt-of
                bussproofs;
            })
          ];
        
          programs.fish = {
            interactiveShellInit = "eval (brew shellenv)";
            functions.pman = "mandoc -T pdf (man -w $argv) | open -fa Preview";
          };
        
          programs.emacs.package = emacsOverlay pkgs pkgs.emacs29-macport;
          home.sessionVariables.EDITOR = "emacsclient";
        
          services.syncthing.enable = true;
        };
        defaultSettings = { config, lib, ... }:
        
        {
          home.activation = {
            activateSettings = lib.hm.dag.entryAfter
              [ "writeBoundary" ] 
              "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u";
          };
        
          targets.darwin.defaults = {
            NSGlobalDomain = {
              AppleInterfaceStyleSwitchesAutomatically = true;
              WebKitDeveloperExtras = true;
            };
        
            "com.apple.dock" = {
              orientation = "left";
              # show-recents = false;
              # static-only = true;
              autohide = true;
            };
        
            # TODO: Change to ~/shared/pictures
            "com.apple.screencapture" = {
              location = config.defaultDirectories.scratchDirectory;
            };
        
            "com.apple.Safari" = {
              AutoOpenSafeDownloads = false;
              SuppressSearchSuggestions = true;
              UniversalSearchEnabled = false;
              AutoFillFromAddressBook = false;
              AutoFillPasswords = false;
              IncludeDevelopMenu = true;
              SandboxBroker.ShowDevelopMenu = true;
              AutoFillCreditCardData = false;
              AutoFillMiscellaneousForms = false;
              ShowFavoritesBar = false;
              WarnAboutFraudulentWebsites = true;
              WebKitJavaEnabled = false;
            };
        
            "com.apple.AdLib" = {
              allowApplePersonalizedAdvertising = false;
            };
        
            "com.apple.finder" = {
              AppleShowAllFiles = true;
              ShowPathbar = true;
            };
        
            "com.apple.print.PrintingPrefs" = {
              "Quit When Finished" = true;
            };
        
            "com.apple.SoftwareUpdate" = {
              AutomaticCheckEnabled = true;
              ScheduleFrequency = 1;
              AutomaticDownload = 1;
              CriticalUpdateInstall = 1;
            };
          };
        };
        linuxHome = { config, pkgs, ... }:
        
          {
            imports = [ home ];
        
            home.homeDirectory = "/home/${config.personal.userName}";
            home.packages = with pkgs; [
              killall
              docker-compose
            ];
        
            services.ssh-agent.enable = true;
            services.gpg-agent.enable = true;
          };
        linuxHomeHeadless = { pkgs, ... }:
          {
            imports = [ linuxHome ];
        
            services.gpg-agent.pinentryFlavor = "tty";
          };
        linuxHomeGraphical = { config, pkgs, ... }:
        
        {
          imports = [ linuxHome emacsConfiguration dconfSettings ];
        
          home.packages = with pkgs; [
            pinentry-gnome
            jetbrains-mono
            source-sans
            source-serif
            (pkgs.texlive.combine {
              inherit (pkgs.texlive) scheme-basic
                dvisvgm dvipng
                wrapfig amsmath ulem hyperref capt-of
                bussproofs;
            })
          
            gnome.dconf-editor
            gnomeExtensions.pop-shell
            whitesur-gtk-theme
            whitesur-icon-theme
            
            slack
            spotify
            playerctl
          ];
          
          xdg.userDirs = {
            createDirectories = true;
            documents = config.defaultDirectories.scratchDirectory;
            download = config.defaultDirectories.scratchDirectory;
            music = "${config.defaultDirectories.shareDirectory}/music";
            pictures = "${config.defaultDirectories.shareDirectory}/pictures";
            publicShare = config.defaultDirectories.scratchDirectory;
            templates = config.defaultDirectories.scratchDirectory;
            videos = "${config.defaultDirectories.shareDirectory}/videos";
          };
          
          fonts.fontconfig.enable = true;
        
          services.gpg-agent.pinentryFlavor = "gnome3";
        
          programs.kitty = {
            enable = true;
            font = { name = "JetBrains Mono"; size = 12; };
          };
          
          programs.firefox = {
            enable = true;
            enableGnomeExtensions = false;
          };
            
          programs.emacs.package = emacsOverlay pkgs pkgs.emacs-unstable-pgtk;
          services.emacs = {
            enable = true;
            package = config.programs.emacs.package;
            defaultEditor = true;
            startWithUserSession = "graphical";
          };
        
          # services.syncthing.enable = true;
        };
        slackOverlay = { pkgs, ... }:
        
        {
          nixpkgs.overlays = [
            (final: prev: {
              slack = prev.slack.overrideAttrs (previous: {
                installPhase = previous.installPhase + ''
                  rm $out/bin/slack
          
                  makeWrapper $out/lib/slack/slack $out/bin/slack \
                  --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
                  --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.xdg-utils]} \
                  --add-flags "--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-webrtc-pipewire-capturer"
                '';
              });
            })
          ];
        };
        dconfSettings = { config, ... }:
        
        {
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
              gtk-theme = "WhiteSur";
              icon-theme = "WhiteSur";
            };
            "org/gnome/desktop/background" = {
              picture-uri = "file://${config.xdg.userDirs.pictures}/deep-field.png";
              picture-uri-dark = "file://${config.xdg.userDirs.pictures}/deep-field.png";
            };
          };
        };
        wireless = ({ config, ... }: 
        
          {
            age.secrets.wireless.file = ./secrets/wireless.age;
            networking.wireless = {
              enable = true;
              environmentFile = config.age.secrets.wireless.path;
              networks."TheShire".psk = "@THE_SHIRE_PSK@";
              networks."DudeCave".psk = "@DUDE_CAVE_PSK@";
            };
          });
        tailscale-autoconnect = { config, lib, pkgs, ... }:
        
        with lib; let
          cfg = config.services.tailscaleAutoConnect;
        in {
          options.services.tailscaleAutoConnect = {
            enable = mkEnableOption "tailscaleAutoConnect";
            authKeyFile = mkOption {
              type = types.str;
              description = "The authkey to use for authentication with Tailscale";
            };
        
            loginServer = mkOption {
              type = types.str;
              default = "";
              description = "The login server to use for authentication with Tailscale";
            };
        
            advertiseExitNode = mkOption {
              type = types.bool;
              default = false;
              description = "Whether to advertise this node as an exit node";
            };
        
            exitNode = mkOption {
              type = types.str;
              default = "";
              description = "The exit node to use for this node";
            };
        
            exitNodeAllowLanAccess = mkOption {
              type = types.bool;
              default = false;
              description = "Whether to allow LAN access to this node";
            };
          };
        
          config = mkIf cfg.enable {
            assertions = [
              {
                assertion = cfg.authKeyFile != "";
                message = "authKeyFile must be set";
              }
              {
                assertion = cfg.exitNodeAllowLanAccess -> cfg.exitNode != "";
                message = "exitNodeAllowLanAccess must be false if exitNode is not set";
              }
              {
                assertion = cfg.advertiseExitNode -> cfg.exitNode == "";
                message = "advertiseExitNode must be false if exitNode is set";
              }
            ];
        
            systemd.services.tailscale-autoconnect = {
              description = "Automatic connection to Tailscale";
        
              # make sure tailscale is running before trying to connect to tailscale
              after = ["network-pre.target" "tailscale.service"];
              wants = ["network-pre.target" "tailscale.service"];
              wantedBy = ["multi-user.target"];
        
              serviceConfig.Type = "oneshot";
        
              script = with pkgs; ''
                # wait for tailscaled to settle
                sleep 2
        
                # check if we are already authenticated to tailscale
                status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
                # if status is not null, then we are already authenticated
                echo "tailscale status: $status"
                if [ "$status" != "NeedsLogin" ]; then
                    exit 0
                fi
        
                # otherwise authenticate with tailscale
                # timeout after 10 seconds to avoid hanging the boot process
                ${coreutils}/bin/timeout 10 ${tailscale}/bin/tailscale up \
                  ${lib.optionalString (cfg.loginServer != "") "--login-server=${cfg.loginServer}"} \
                  --authkey=$(cat "${cfg.authKeyFile}")
        
                # we have to proceed in two steps because some options are only available
                # after authentication
                ${coreutils}/bin/timeout 10 ${tailscale}/bin/tailscale up \
                  ${lib.optionalString (cfg.loginServer != "") "--login-server=${cfg.loginServer}"} \
                  ${lib.optionalString (cfg.advertiseExitNode) "--advertise-exit-node"} \
                  ${lib.optionalString (cfg.exitNode != "") "--exit-node=${cfg.exitNode}"} \
                  ${lib.optionalString (cfg.exitNodeAllowLanAccess) "--exit-node-allow-lan-access"}
              '';
            };
        
            networking.firewall = {
              trustedInterfaces = ["tailscale0"];
              allowedUDPPorts = [config.services.tailscale.port];
            };
        
            services.tailscale = {
              enable = true;
              useRoutingFeatures =
                if cfg.advertiseExitNode
                then "server"
                else "client";
            };
          };
        };
        homeManagerNixOSModule = module: inputs:
          {
            imports = [ personal ];
        
            home-manager.users.${inputs.config.personal.userName} = (module inputs);
          };
        emacsOverlay = (pkgs: package:
          (pkgs.emacsWithPackagesFromUsePackage {
            inherit package;
            config = ./emacs.el;
            defaultInitFile = true;
            extraEmacsPackages = epkgs: with epkgs; [ treesit-grammars.with-all-grammars ];
            alwaysEnsure = true;
          }));
        emacsConfiguration = { pkgs, ... }:
        
          {
            nixpkgs.overlays = with emacs-overlay.overlays; [ emacs package ];
        
            programs.emacs.enable = true;
          };
      };
      darwinConfigurations.kenobi = nix-darwin.lib.darwinSystem {
        modules = with nixosModules; [
          darwinSystem
          {
            nixpkgs.hostPlatform = "x86_64-darwin";
          }
        ];
      };
      homeConfigurations."jackson@kenobi" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-darwin";
          config.allowUnfree = true;
        };
        modules = with nixosModules; [ darwinHome ];
        extraSpecialArgs.nixcasks = nixcasks.legacyPackages."x86_64-darwin";
      };
      nixosConfigurations.share1 = nixpkgs.lib.nixosSystem {
        modules = [ nixosModules.share1 ];
      };
      nixosConfigurations.share1Image = nixpkgs.lib.nixosSystem {
        modules = [
          nixosModules.share1
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ({ config, ... }: {
            users.users.${config.personal.userName}.initialPassword = "password";
            users.users.root.initialPassword = "password";
          })
        ];
      };
      packages.aarch64-linux.share1Image = nixosConfigurations.share1Image.config.system.build.sdImage;
      formatter = nixpkgs.lib.genAttrs [ "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (system: {
        system = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
      });
      templates.rust = {
        path = ./templates/rust;
        description = "Rust template";
      };
      templates.python = {
        path = ./templates/python;
        description = "Python template";
      };
      templates.herbie = {
        path = ./templates/herbie;
        description = "Herbie template";
      };
      templates.coq = {
        path = ./templates/coq;
        description = "Coq template";
      };
    };
}

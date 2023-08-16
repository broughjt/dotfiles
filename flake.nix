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
    let
      modules = rec {
        personal = { config, lib, ... }:
        
          {
            options.personal = {
              userName = lib.mkOption { type = lib.types.str; default = "jackson"; };
              fullName = lib.mkOption { type = lib.types.str; default = "Jackson Brough"; };
              email = lib.mkOption { type = lib.types.str; default = "jacksontbrough@gmail.com"; };
              repositoriesDirectory = lib.mkOption {
                type = lib.types.str; 
                default = "${config.home.homeDirectory}/repositories";
              };
              localDirectory = lib.mkOption {
                type = lib.types.str; 
                default = "${config.home.homeDirectory}/local";
              };
              scratchDirectory = lib.mkOption {
                type = lib.types.str; 
                default = "${config.home.homeDirectory}/scratch";
              };
              shareDirectory = lib.mkOption {
                type = lib.types.str; 
                default = "${config.home.homeDirectory}/share";
              };
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
        darwinSystem = { config, pkgs, ... }:
        
          {
            imports = [ system ];
        
            config = {
              services.nix-daemon.enable = true;
              system.configurationRevision = self.rev or self.dirtyRev or null;
              system.stateVersion = 4;
        
              users.users.${config.personal.userName}.home = "/Users/${config.personal.userName}";
        
              homebrew.enable = true;
              homebrew.casks = [ "spotify" "zoom" ];
            };
          };
        linuxSystem = { config, pkgs, ... }:
        
          {
            imports = [ system ];
        
            system.stateVersion = "23.05";
        
            users.users.${config.personal.userName} = {
              home = "/home/${config.personal.userName}";
              extraGroups = [ "wheel" ];
              isNormalUser = true;
            };
        
            services.openssh = {
              enable = true;
              settings.PasswordAuthentication = true;
              settings.KbdInteractiveAuthentication = true;
            };
          };
        home = { lib, config, pkgs, ... }:
        
          {
            imports = [ personal ];
        
            nixpkgs.overlays = [ agenix.overlays.default ];
        
            home.username = config.personal.userName;
            home.stateVersion = "23.05";
            home.packages = with pkgs; [
              pkgs.agenix
              exa
              jq
              ripgrep
                
              direnv
              gopass
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
                    path = ${config.personal.repositoriesDirectory}/passwords
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
          home.packages = with pkgs; [ nixcasks.slack jetbrains-mono ];
        
          programs.fish.interactiveShellInit = "eval (brew shellenv)";
        
          programs.emacs.package = emacsOverlay pkgs pkgs.emacs29-macport;
          home.sessionVariables.EDITOR = "emacsclient";
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
              show-recents = false;
              static-only = true;
              autohide = true;
            };
        
            # TODO: Change to ~/shared/pictures
            "com.apple.screencapture" = {
              location = config.personal.scratchDirectory;
            };
        
            "com.apple.Safari" = {
              AutoOpenSafeDownloads = false;
              SuppressSearchSuggestions = true;
              UniversalSearchEnabled = false;
              AutoFillFromAddressBook = false;
              AutoFillPasswords = false;
              IncludeDevelopMenu = false;
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
              lldb
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
          imports = [ linuxHome emacsConfiguration dconfSettings slackOverlay ];
        
          home.packages = with pkgs; [
            pinentry-gnome
            jetbrains-mono
            source-sans
            source-serif
          
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
            documents = config.personal.scratchDirectory;
            download = config.personal.scratchDirectory;
            music = "${config.personal.shareDirectory}/music";
            pictures = "${config.personal.shareDirectory}/pictures";
            publicShare = config.personal.scratchDirectory;
            templates = config.personal.scratchDirectory;
            videos = "${config.personal.shareDirectory}/videos";
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
        tailscale-autoconnect = { config, lib, pkgs, ... }:
        
        with lib; let
          cfg = config.services.tailscaleAutoconnect;
        in {
          options.services.tailscaleAutoconnect = {
            enable = mkEnableOption "tailscaleAutoconnect";
            authkeyFile = mkOption {
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
                assertion = cfg.authkeyFile != "";
                message = "authkeyFile must be set";
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
                  --authkey=$(cat "${cfg.authkeyFile}")
        
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
    in with modules; {
      nixosModules = modules;
      nixosConfigurations.murph = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ({ config, lib, modulesPath, pkgs, ... }:
      
           {
             imports = [
               (modulesPath + "/installer/scan/not-detected.nix")
               linuxSystem
             ];
      
             boot = {
               kernelModules = [ "kvm-intel" ];
               kernelParams = [ "mem_sleep_default=deep" ];
               loader.systemd-boot.enable = true;
               loader.efi.canTouchEfiVariables = true;
               initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
               initrd.secrets = { "/crypto_keyfile.bin" = null; };
             };
      
             fileSystems."/" =
               {
                 device = "/dev/disk/by-uuid/5ab3b7b9-8ec3-4d65-848a-6c338e278219";
                 fsType = "ext4";
               };
             boot.initrd.luks.devices."luks-d2fca484-d24f-4d68-b08f-882533b0b987".device = "/dev/disk/by-uuid/d2fca484-d24f-4d68-b08f-882533b0b987";
             fileSystems."/boot" =
               {
                 device = "/dev/disk/by-uuid/990E-C2F5";
                 fsType = "vfat";
               };
      
             networking.hostName = "murph";
             networking.networkmanager.enable = true;
             networking.useDHCP = lib.mkDefault true;
      
             powerManagement.enable = true;
             powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
      
             hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      
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
      
             nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      
             users.users.${config.personal.userName}.extraGroups = [ "networkmanager" "video" ];
           })
        ];
      };
      homeConfigurations."jackson@murph" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        modules = [ linuxHomeGraphical ];
      };
      nixosConfigurations.share1 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ({ config, modulesPath, lib, pkgs, ... }:
      
           {
             imports = [
               (modulesPath + "/installer/scan/not-detected.nix")
               linuxSystem
               tailscale-autoconnect
             ];
      
             boot = {
               kernelPackages = pkgs.linuxKernel.packages.linux_rpi3;
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
      
             hardware.enableRedistributableFirmware = true;
      
             networking.hostName = "share1";
             networking.networkmanager.enable = true;
      
             powerManagement.enable = true;
             powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
      
             nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
      
             environment.systemPackages = [ pkgs.tailscale ];
      
             services.tailscaleAutoconnect = {
               enable = true;
               authKeyFile = ../secrets/share1-auth-key1.age;
               loginServer = "https://login.tailscale.com";
             };
      
             users.users.${config.personal.userName}.extraGroups = [ "networkmanager" ];
           })
        ];
      };
      homeConfigurations."jackson@share1" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-linux";
          config.allowUnfree = true;
        };
        modules = [ linuxHomeHeadless ];
      };
         darwinConfigurations.kenobi = nix-darwin.lib.darwinSystem {
           modules = [
        darwinSystem
       (inputs: { nixpkgs.hostPlatform = "x86_64-darwin"; })
      ];
         };
         homeConfigurations."jackson@kenobi" = home-manager.lib.homeManagerConfiguration {
           pkgs = import nixpkgs {
             system = "x86_64-darwin";
             config.allowUnfree = true;
           };
           modules = [
          darwinHome
          ];
           extraSpecialArgs.nixcasks = nixcasks.legacyPackages."x86_64-darwin";
         };
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixpkgs-fmt;
      templates.rust = {
        path = ./templates/rust;
        description = "Rust template";
      };
      templates.herbie = {
        path = ./templates/herbie;
        description = "Herbie template";
      };
  };
}

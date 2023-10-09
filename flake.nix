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
              homebrew.casks = [ "spotify" "zoom" "docker" "discord" ];
        
              services.tailscale.enable = true;
            };
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
        raspberryPi4 = ({config, modulesPath, lib, pkgs, ... }:
        
          {
            imports = [
              linuxSystem
            ];
        
            boot = {
              kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
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
            
            age.secrets.share1-auth-key1.file = ./secrets/share1-auth-key1.age;
            services.tailscaleAutoConnect = {
              enable = true;
              authKeyFile = config.age.secrets.share1-auth-key1.path;
              loginServer = "https://login.tailscale.com";
            };
            
            services.syncthing = {
              enable = true;
              user = config.personal.userName;
              dataDir = config.users.users.${config.personal.userName}.home;
              guiAddress = "0.0.0.0:8384";
            };
          });
        share1 = ({ config, pkgs, ... }:
        
          {
            imports = [
              raspberryPi4
              wireless
              share
            ];
        
            networking.hostName = "share1";
        
            nixpkgs.hostPlatform = "aarch64-linux";
          });
        hetzner = ({ config, lib, pkgs, modulesPath, ... }:
        
          {
            imports = [
              (modulesPath + "/profiles/qemu-guest.nix")
              linuxSystem
            ];
        
            boot = {
              cleanTmpDir = true;
              loader.grub = {
                efiSupport = true;
                efiInstallAsRemovable = true;
                device = "nodev";
              };
              initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" ];
              initrd.kernelModules = [ "nvme" ];
            };
            zramSwap.enable = true;
        
            fileSystems."/" = {
              device = "/dev/sda1";
              fsType = "ext4";
            };
          });
        hetzner1 = ({ config, lib, ... }:
        
          {
            imports = [ hetzner ];
        
            fileSystems."/boot" = {
              device = "/dev/disk/by-uuid/77CF-345D"; fsType = "vfat";
            };
        
            networking = {
              hostName = "hetzner1";
              nameservers = [ "8.8.8.8" ];
              defaultGateway = "172.31.1.1";
              defaultGateway6 = {
                address = "fe80::1";
                interface = "eth0";
              };
              dhcpcd.enable = false;
              usePredictableInterfaceNames = lib.mkForce false;
              interfaces = {
                eth0 = {
                  ipv4.addresses = [
                    { address="65.21.158.247"; prefixLength=32; }
                  ];
                  ipv6.addresses = [
                    { address="2a01:4f9:c012:9c1b::1"; prefixLength=64; }
                    { address="fe80::9400:2ff:fe9b:f68d"; prefixLength=64; }
                  ];
                  ipv4.routes = [ { address = "172.31.1.1"; prefixLength = 32; } ];
                  ipv6.routes = [ { address = "fe80::1"; prefixLength = 128; } ];
                };
                
              };
            };
            services.udev.extraRules = ''
              ATTR{address}=="96:00:02:9b:f6:8d", NAME="eth0"
            '';
        
            users.users.${config.personal.userName}.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBndIK51b/o6aSjuTdoa8emnpCRg0s5y68oXAFR66D4/ jacksontbrough@gmail.com" ];
            users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBndIK51b/o6aSjuTdoa8emnpCRg0s5y68oXAFR66D4/ jacksontbrough@gmail.com" ];
        
            nixpkgs.hostPlatform = "aarch64-linux";
          });
        murph = ({ config, lib, modulesPath, pkgs, ... }:
          
          {
            imports = [
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
            
            services.openssh = {
              settings.PasswordAuthentication = true;
              settings.KbdInteractiveAuthentication = true;
            };
            
            services.tailscale.enable = true;
            
            users.users.${config.personal.userName}.extraGroups = [ "networkmanager" "video" ];
          });
        home = { lib, config, pkgs, ... }:
        
          {
            imports = [ personal ];
        
            nixpkgs.overlays = [ agenix.overlays.default ];
        
            home.username = config.personal.userName;
            home.stateVersion = "23.05";
            home.packages = with pkgs; [
              pkgs.agenix
              eza
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
          home.packages = with pkgs; [
            nixcasks.slack
            # Seems to be broken
            # nixcasks.docker
            jetbrains-mono
            (pkgs.texlive.combine {
              inherit (pkgs.texlive) scheme-basic
                dvisvgm dvipng
                wrapfig amsmath ulem hyperref capt-of;
            })
          ];
        
          programs.fish.interactiveShellInit = "eval (brew shellenv)";
        
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
              location = config.personal.scratchDirectory;
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
              lldb
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
                wrapfig amsmath ulem hyperref capt-of;
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
        
          services.syncthing.enable = true;
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
              networks."The Shire".psk = "@THE_SHIRE_PSK@";
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
        syncthing = ({ config, pkgs, ... }:
        
          {
            imports = [ personal ];
        
            services.syncthing = {
              enable = true;
              dataDir = config.users.users.${config.personal.userName}.home;
              openDefaultPorts = true;
              # TODO: Sync up with home manager xdg directories some how?
              user = config.personal.userName;
              guiAddress = "0.0.0.0:8384";
              declarative = {
                overrideDevices = true;
                overrideFolders = true;
                # devices = todo generate from personal.machines.all.syncthingIds - networking.hostName;
                # folders = list devices should be folder, substract networking.hostName
              };
            };
        
            users.users.${config.personal.userName}.extraGroups = [ "syncthing" ];
          });
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
      nixosConfigurations.murph = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ nixosModules.murph ];
      };
      homeConfigurations."jackson@murph" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        modules = [ nixosModules.linuxHomeGraphical ];
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
        modules = with nixosModules; [
          darwinHome
          ({ config, ... }: {
            programs.ssh.matchBlocks."nix-docker" = {
              user = "root";
              hostname = "127.0.0.1";
              port = 3022;
              identityFile = config.home.homeDirectory + "/.ssh/docker_rsa";
            };
          })
        ];
        extraSpecialArgs.nixcasks = nixcasks.legacyPackages."x86_64-darwin";
      };
      
      
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

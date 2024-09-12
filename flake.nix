{
  description = "Are these your configuration files, Larry?";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, emacs-overlay }:
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
        packageManager = { pkgs, ... }:
        
          {
            nix.package = pkgs.nix;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            nixpkgs.config.allowUnfree = true;
          };
        murphHardware = { config, pkgs, lib, ... }:
        
          {
            hardware.enableRedistributableFirmware = lib.mkDefault true;
            hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        
            nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        
            system.stateVersion = "23.11";
        
            boot = {
              initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ];
              initrd.kernelModules = [ ];
              kernelPackages = pkgs.linuxPackages_latest;
              kernelModules = [ "kvm-amd" ];
              extraModulePackages = [ ];
              loader.systemd-boot.enable = true;
              loader.efi.canTouchEfiVariables = true;
            };
        
            fileSystems."/boot" = {
              device = "/dev/disk/by-uuid/79D4-F8F1";
              fsType = "vfat";
              options = [ "fmask=0022" "dmask=0022" ];
            };
            fileSystems."/" = {
              device = "/dev/disk/by-uuid/570b2e37-fe1d-47d0-be0c-457f37d4bc3d";
              fsType = "ext4";
            };
            swapDevices = [ ];
        
            networking.hostName = "murph";
            networking.networkmanager.enable = true;
            networking.useDHCP = lib.mkDefault true;
        
            security.rtkit.enable = true;
            services.pipewire = {
              enable = true;
              pulse.enable = true;
              alsa.enable = true;
              alsa.support32Bit = true;
            };
        
            hardware.bluetooth.enable = true;
            services.blueman.enable = true;
        
            services.fprintd.enable = true;
        
            security.polkit.enable = true;
            hardware.graphics.enable = true;
        
            services.fwupd.enable = true;
        
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
        
            services.xserver = {
              xkb.layout = "us";
              xkb.variant = "";
            };
        
            # TODO: For ECE 3710 FPGA, remove when finished with the class
            services.udev.extraRules = ''
            SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6001", MODE="0666"
            SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6002", MODE="0666"
            SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6003", MODE="0666"
        
            SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6010", MODE="0666"
            SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6810", MODE="0666"
            '';
          };
        jacksonUserLinux = { config, pkgs, ... }:
        
          {
            nix.settings.trusted-users = [ "root" config.personal.userName ];
        
            environment.systemPackages = with pkgs; [ curl git neovim ];
            environment.shells = with pkgs; [ bashInteractive fish ];
        
            programs.fish.enable = true;
        
            users.users.${config.personal.userName} = {
              home = "/home/${config.personal.userName}";
              extraGroups = [ "wheel" "networkmanager" "video" "input" ];
              shell = pkgs.fish;
              isNormalUser = true;
            };
        
            services.openssh.enable = true;
          };
        docker = { config, pkgs, ... }:
        
          {
            virtualisation.docker.enable = true;
        
            users.users.${config.personal.userName}.extraGroups = [ "docker" ];
          };
        homeLinux = { config, pkgs, ... }:
          
          {
            home-manager.users.${config.personal.userName} = let
              homeDirectory = "/home/${config.personal.userName}";
            in {
              home.stateVersion = "23.05";
              programs.home-manager.enable = true;
              home.homeDirectory = homeDirectory;
        
              xdg = {
                enable = true;
                cacheHome = "${homeDirectory}/.cache";
                configHome = "${homeDirectory}/.config";
                dataHome = "${homeDirectory}/.local/share";
                stateHome = "${homeDirectory}/.local/state";
                # mimeApps = {
                #   enable = true;
                #   defaultApplications = {
                #     "application/pdf" = "firefox.desktop";
                #   };
                # };
              };
        
              home.packages = with pkgs; [
                direnv
                eza
                fd
                ispell
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
                userName = config.personal.fullName;
                userEmail = config.personal.email;
                signing.key = "1BA5F1335AB45105";
                signing.signByDefault = config.home-manager.users.${config.personal.userName}.programs.gpg.enable;
                # "Are the worker threads going to unionize?"
                extraConfig.init.defaultBranch = "main";
              };
              
              programs.ssh.enable = true;
            };
          };
        homeLinuxGraphical = { config, pkgs, lib, ... }:
        
          {
            imports = [ dconf ];
        
            options = let
              homeDirectory = config.home-manager.users.${config.personal.userName}.home.homeDirectory; in
              {
                defaultDirectories.repositoriesDirectory = lib.mkOption { type = lib.types.str; default = "${homeDirectory}/repositories"; };
                defaultDirectories.localDirectory = lib.mkOption { type = lib.types.str; default = "${homeDirectory}/local"; };
                defaultDirectories.scratchDirectory = lib.mkOption { type = lib.types.str; default = "${homeDirectory}/scratch"; };
                defaultDirectories.shareDirectory = lib.mkOption { type = lib.types.str; default = "${homeDirectory}/share"; };
              };
        
            config = {
              services.xserver = {
                enable = true;
                displayManager.gdm.enable = true;
                displayManager.gdm.wayland = true;
                desktopManager.gnome.enable = true;
              };
              hardware.pulseaudio.enable = false;
              
              environment.gnome.excludePackages = (with pkgs; [
                gnome-photos
                gnome-tour
                gedit
                cheese
                epiphany
                evince
                geary
                totem
                gnome-calculator
                gnome-calendar
                simple-scan
              ]) ++ (with pkgs.gnome; [
                atomix
                gnome-characters
                gnome-music
                hitori
                iagno
                tali
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
              ]);
        
              home-manager.users.${config.personal.userName} = {
                home.packages = with pkgs; [
                  jetbrains-mono
                  noto-fonts
                  
                  dconf-editor
                  discord # Eww cringe, but everyone uses it for class group chats
                  firefox
                  slack
                  spotify
                  evince
                  
                  # Say no to globally installed tex
                  # (pkgs.texlive.combine {
                    # inherit (pkgs.texlive) scheme-basic
                      # dvisvgm dvipng
                      # wrapfig amsmath ulem hyperref capt-of
                      # bussproofs simplebnf tabularray mathtools;
                  # })
                ];
                home.sessionVariables.NIXOS_OZONE_WL = "1";
                
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
                xdg.portal = {
                  enable = true;
                  config = {
                    common = {
                      default = [
                        "gtk"
                      ];
                    };
                  };
                  extraPortals = with pkgs; [
                    xdg-desktop-portal-wlr
                    xdg-desktop-portal-gtk
                  ];
                };
                
                programs.beets = {
                  enable = true;
                  settings = {
                    directory = "${config.defaultDirectories.shareDirectory}/music";
                    import.move = true;
                  };
                };
        
                fonts.fontconfig = {
                  enable = true;
                  defaultFonts.monospace = [ "JetBrains Mono" "Noto Sans Mono" ];
                  defaultFonts.sansSerif = [ "Noto Sans" ];
                  defaultFonts.serif = [ "Noto Serif" ];
                };
        
                # services.mpd = {
                # enable = true;
                # musicDirectory = "${config.defaultDirectories.shareDirectory}/music";
                # extraConfig = ''
                # audio_output {
                # type "pipewire"
                # name "pipewire"
                # }
                # '';
                # };
                
                # services.mpd-mpris.enable = true;
                # services.playerctld.enable = true;
              };
            };
          };
        dconf = { config, lib, ... }:
          {
            home-manager.users.${config.personal.userName}.dconf = {
              enable = true;
              settings = {
                "org/gnome/desktop/wm/keybindings" = {
                  close = [ "<Super>q" ];
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
                "org/gnome/desktop/wm/preferences" = {
                  num-workspaces = 9;
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
                "org/gnome/shell" = {
                  disabled-user-extension = false;
                  disabled-extensions = "disabled";
                };
                "org/gnome/desktop/interface" = {
                  scaling-factor = home-manager.lib.hm.gvariant.mkUint32 2;
                  color-scheme = "prefer-dark";
                  enable-hot-cornors = false;
                  clock-format = "12h";
                };
                "org/gnome/desktop/background" = {
                  picture-options = "none";
                  color-shading-type = "solid";
                  primary-color = "#0a369d";
                };
              };
            };
          };
        gh = { config, pkgs, ... }:
        
          {
            home-manager.users.${config.personal.userName} = {
              programs.gh = {
                enable = true;
                settings.git_protocol = "ssh";
              };
            };
          };
        gpg = { config, pkgs, ... }:
        
          {
            home-manager.users.${config.personal.userName} = {
              home.packages = with pkgs; [ pinentry-gnome3 ];
              
              services.ssh-agent.enable = pkgs.stdenv.isLinux;
              
              programs.gpg = {
                enable = true;
                homedir = let xdgDataHome = config.home-manager.users.${config.personal.userName}.xdg.dataHome;
                          in "${xdgDataHome}/gnupg";
              };
              services.gpg-agent = {
                enable = pkgs.stdenv.isLinux;
                pinentryPackage = pkgs.pinentry-gnome3;
              };
            };
          };
        gopass = { config, pkgs, ... }:
        
          {
            home-manager.users.${config.personal.userName} = {
              home.packages = [ pkgs.gopass ];
              
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
          };
        tailscale = { config, ... }:
          {
            services.tailscale.enable = true;
            services.tailscale.useRoutingFeatures = "client";
          };
        emacsOverlay = (pkgs: package:
          (pkgs.emacsWithPackagesFromUsePackage {
            inherit package;
            config = ./emacs.el;
            defaultInitFile = true;
            extraEmacsPackages = epkgs: with epkgs; [
              treesit-grammars.with-all-grammars
            ];
            override = epkgs: epkgs // {
              lean4-mode = epkgs.trivialBuild rec {
                pname = "lean4-mode";
                version = "1";
                src = pkgs.fetchFromGitHub {
                  owner = "bustercopley";
                  repo = "lean4-mode";
                  rev = "f6166f65ac3a50ba32282ccf2c883d61b5843a2b";
                  sha256 = "sha256-mVZh+rP9IWLs2QiPysIuQ3uNAQsuJ63xgUY5akaJjXc=";
                };
                propagatedUserEnvPkgs = with epkgs;
                  [ dash f flycheck lsp-mode magit-section s ];
                buildInputs = propagatedUserEnvPkgs;
                postInstall = ''
                  DATADIR=$out/share/emacs/site-lisp/data
                  mkdir $DATADIR
                  install ./data/abbreviations.json $DATADIR
                '';
              };
            };
            alwaysEnsure = true;
          }));
        emacsConfiguration = { config, pkgs, ... }:
        
          {
            nixpkgs.overlays = with emacs-overlay.overlays; [ emacs package ];
        
            home-manager.users.${config.personal.userName} = {
              programs.emacs = {
                enable = true;
                package = pkgs.emacsWithPackagesFromUsePackage {
                  package = pkgs.emacs-unstable-pgtk;
                  config = ./emacs.el;
                  defaultInitFile = true;
                  extraEmacsPackages = epkgs: with epkgs; [
                    treesit-grammars.with-all-grammars
                  ];
                  override = epkgs: epkgs // {
                    lean4-mode = epkgs.trivialBuild rec {
                      pname = "lean4-mode";
                      version = "1";
                      src = pkgs.fetchFromGitHub {
                        owner = "bustercopley";
                        repo = "lean4-mode";
                        rev = "f6166f65ac3a50ba32282ccf2c883d61b5843a2b";
                        sha256 = "sha256-mVZh+rP9IWLs2QiPysIuQ3uNAQsuJ63xgUY5akaJjXc=";
                      };
                      propagatedUserEnvPkgs = with epkgs;
                        [ dash f flycheck lsp-mode magit-section s ];
                      buildInputs = propagatedUserEnvPkgs;
                      postInstall = ''
                        DATADIR=$out/share/emacs/site-lisp/data
                        mkdir $DATADIR
                        install ./data/abbreviations.json $DATADIR
                      '';
                    };
                  };
                  alwaysEnsure = true;
                };
              };
              services.emacs = {
                enable = pkgs.stdenv.isLinux;
                package = config.home-manager.users.${config.personal.userName}.programs.emacs.package;
                defaultEditor = true;
              };
            };
          };
      };
      nixosConfigurations.murph = nixpkgs.lib.nixosSystem {
        modules = with nixosModules; [
          murphHardware
          packageManager
          jacksonUserLinux
          docker
          # TODO:
          # tailscale
          home-manager.nixosModules.home-manager
          personal
          homeLinux
          homeLinuxGraphical
          gh
          gpg
          gopass
          emacsConfiguration
        ];
      };
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

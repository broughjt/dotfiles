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
            hardware.opengl.enable = true;
        
            services.fwupd.enable = true;
        
            time.timeZone = "America/Los_Angeles";
        
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
            options = let
              homeDirectory = config.home-manager.users.${config.personal.userName}.home.homeDirectory; in
              {
                defaultDirectories.repositoriesDirectory = lib.mkOption { type = lib.types.str; default = "${homeDirectory}/repositories"; };
                defaultDirectories.localDirectory = lib.mkOption { type = lib.types.str; default = "${homeDirectory}/local"; };
                defaultDirectories.scratchDirectory = lib.mkOption { type = lib.types.str; default = "${homeDirectory}/scratch"; };
                defaultDirectories.shareDirectory = lib.mkOption { type = lib.types.str; default = "${homeDirectory}/share"; };
              };
        
            config.home-manager.users.${config.personal.userName} = {
              home.packages = with pkgs; [
                jetbrains-mono
                noto-fonts
                gnome.adwaita-icon-theme
                
                brightnessctl
                playerctl
                mpc-cli
                nicotine-plus
                slack
                spotify
                ungoogled-chromium
                
                (pkgs.texlive.combine {
                  inherit (pkgs.texlive) scheme-basic
                    dvisvgm dvipng
                    wrapfig amsmath ulem hyperref capt-of
                    bussproofs simplebnf tabularray mathtools;
                })
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
              
              fonts.fontconfig = {
                enable = true;
                defaultFonts.monospace = [ "JetBrains Mono" "Noto Sans Mono" ];
                defaultFonts.sansSerif = [ "Noto Sans" ];
                defaultFonts.serif = [ "Noto Serif" ];
              };
              
              wayland.windowManager.sway = let
                terminal = "foot";
                modifier = "Mod4";
              in {
                enable = true;
                wrapperFeatures.gtk = true;
                config = {
                  terminal = terminal;
                  modifier = modifier;
                  input = {
                    "type:touchpad" = {
                      "natural_scroll" = "enabled";
                    };
                  };
                  fonts.names = [ "monospace" ];
                  window.border = 0;
                  window.titlebar = false;
                  window.hideEdgeBorders = "smart";
                  # seat."*".xcursor_theme = "Adwaita 18";
                  keybindings = {
                    "${modifier}+q" = "kill";
                    "${modifier}+t" = "exec ${terminal}";
                    "${modifier}+b" = "exec chromium";
                    "${modifier}+e" = "exec emacsclient -c";
                    "${modifier}+d" = "exec tofi-drun | xargs swaymsg exec --";
                    "${modifier}+c" = "exit";
                    "${modifier}+r" = "reload";
                    "${modifier}+f" = "fullscreen";
                    
                    "${modifier}+h" = "focus left";
                    "${modifier}+j" = "focus down";
                    "${modifier}+k" = "focus up";
                    "${modifier}+l" = "focus right";
                    
                    "${modifier}+g" = "splith";
                    "${modifier}+v" = "splitv";
                    "${modifier}+Shift+f" = "floating toggle";
                    "${modifier}+z" = "sticky toggle";
                    
                    "XF86AudioRaiseVolume" = "exec 'wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+'";
                    "XF86AudioLowerVolume" = "exec 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-'";
                    "XF86AudioMute" = "exec 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'";
                    "XF86AudioPlay"= "exec `playerctl play-pause`";
                    "XF86AudioPrev"= "exec `playerctl previous`";
                    "XF86AudioNext"= "exec `playerctl next`";
                    "XF86MonBrightnessDown"= "exec `brightnessctl set 10%-`";
                    "XF86MonBrightnessUp"= "exec `brightnessctl set 10%+`";
                    
                    # TODO: mako, grim, slurp, wl-clipboard
                    # TODO: Floating mode focus
                    # TODO: Resizing windows
                    
                    "${modifier}+Shift+h" = "move left";
                    "${modifier}+Shift+j" = "move down";
                    "${modifier}+Shift+k" = "move up";
                    "${modifier}+Shift+l" = "move right";
                    
                    "${modifier}+1" = "workspace number 1";
                    "${modifier}+2" = "workspace number 2";
                    "${modifier}+3" = "workspace number 3";
                    "${modifier}+4" = "workspace number 4";
                    "${modifier}+5" = "workspace number 5";
                    "${modifier}+6" = "workspace number 6";
                    "${modifier}+7" = "workspace number 7";
                    "${modifier}+8" = "workspace number 8";
                    "${modifier}+9" = "workspace number 9";
                    "${modifier}+0" = "workspace number 10";
                    
                    "${modifier}+Shift+1" = "move container workspace number 1";
                    "${modifier}+Shift+2" = "move container workspace number 2";
                    "${modifier}+Shift+3" = "move container workspace number 3";
                    "${modifier}+Shift+4" = "move container workspace number 4";
                    "${modifier}+Shift+5" = "move container workspace number 5";
                    "${modifier}+Shift+6" = "move container workspace number 6";
                    "${modifier}+Shift+7" = "move container workspace number 7";
                    "${modifier}+Shift+8" = "move container workspace number 8";
                    "${modifier}+Shift+9" = "move container workspace number 9";
                    "${modifier}+Shift+0" = "move container workspace number 10";
                  };
                };
              };
              
              home.pointerCursor = {
                name = "Adwaita";
                gtk.enable = true;
                package = pkgs.phinger-cursors; 
                # package = pkgs.gnome.adwaita-icon-theme;
                size = 48;
              };
              
              programs.foot = {
                enable = true;
                settings = {
                  main = {
                    font = let
                      defaultMonospace = builtins.head config.fonts.fontconfig.defaultFonts.monospace;
                    in "${defaultMonospace}:size=10";
                    dpi-aware = "yes";
                  };
                  mouse.hide-when-typing = "yes";
                };
              };
              
              programs.tofi = {
                enable = true;
                settings = {
                  anchor = "top";
                  width = "100%";
                  height = 30;
                  horizontal = true;
                  background-color = "#000000";
                  font-size = 14;
                  font = "monospace";
                  padding-top = 0;
                  padding-bottom = 0;
                  padding-left = 0;
                  padding-right = 0;
                  border-width = 0;
                  outline-width = 0;
                  result-spacing = 15;
                  min-input-width = 120;
                };
              };
              
              programs.beets = {
                enable = true;
                settings = {
                  directory = "${config.defaultDirectories.shareDirectory}/music";
                  import.move = true;
                };
              };
              
              services.mpd = {
                enable = true;
                musicDirectory = "${config.defaultDirectories.shareDirectory}/music";
                extraConfig = ''
                            audio_output {
                            type "pipewire"
                            name "pipewire"
                            }
                            '';
              };
              
              services.mpd-mpris.enable = true;
              services.playerctld.enable = true;
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
              home.packages = with pkgs; [ pinentry-qt ];
              
              services.ssh-agent.enable = pkgs.stdenv.isLinux;
              
              programs.gpg = {
                enable = true;
                homedir = let xdgDataHome = config.home-manager.users.${config.personal.userName}.xdg.dataHome;
                          in "${xdgDataHome}/gnupg";
              };
              services.gpg-agent = {
                enable = pkgs.stdenv.isLinux;
                pinentryPackage = pkgs.pinentry-qt;
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

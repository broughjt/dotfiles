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
            nix.package = pkgs.nix;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
        
            nixpkgs.config.allowUnfree = true;
          };
        system = { config, pkgs, ... }:
        
          {
            imports = [ package-manager personal ];
        
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
              homebrew.casks = [
                "discord"
                "docker"
                "slack"
                "spotify"
                "zoom"
              ];
        
              services.tailscale.enable = true;
            };
          };
        home = { lib, config, pkgs, ... }:
        
          {
            imports = [ personal defaultDirectories ];
        
            nixpkgs.overlays = [ agenix.overlays.default ];
        
            home.username = config.personal.userName;
            home.stateVersion = "23.05";
            home.packages = with pkgs; [
              direnv
              eza
              fd
              gopass
              ispell
              jq
              lldb
              pkgs.agenix
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
            jetbrains-mono
            (pkgs.texlive.combine {
              inherit (pkgs.texlive) scheme-basic
                dvisvgm dvipng
                wrapfig amsmath ulem hyperref capt-of
                bussproofs simplebnf tabularray mathtools;
            })
          ];
        
          programs.fish = {
            interactiveShellInit = "eval (brew shellenv)";
            functions.pman = "mandoc -T pdf (man -w $argv) | open -fa Preview";
          };
        
          programs.emacs.package = emacsOverlay pkgs pkgs.emacsMacport;
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
              autohide = true;
            };
        
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
        murphHardware = { config, pkgs, lib, ... }:
          
          {
            hardware.enableRedistributableFirmware = lib.mkDefault true;
            hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        
            nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        
            system.stateVersion = "23.11";
        
            boot = {
              initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ];
              initrd.kernelModules = [ ];
              kernelModules = [ "kvm-amd" ];
              extraModulePackages = [ ];
              loader.systemd-boot.enable = true;
              loader.efi.canTouchEfiVariables = true;
            };
        
            fileSystems."/boot" = {
              device = "/dev/disk/by-uuid/AF19-A317";
              fsType = "vfat";
              options = [ "fmask=0022" "dmask=0022" ];
            };
            fileSystems."/" = {
              device = "/dev/disk/by-uuid/3cdd5c2c-ae93-4c4b-a586-cba97469f8e4";
              fsType = "ext4";
            };
            boot.initrd.luks.devices."luks-ab135bff-da1a-44ed-a055-5eaa34b1283d".device = "/dev/disk/by-uuid/ab135bff-da1a-44ed-a055-5eaa34b1283d";
            swapDevices = [ ];
        
            networking.hostName = "nixos";
            networking.networkmanager.enable = true;
            networking.useDHCP = lib.mkDefault true;
        
            # Non murph specific stuff
            time.timeZone = "America/Boise";
        
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
            
            users.users.jackson = {
              isNormalUser = true;
              description = "Jackson Brough";
              extraGroups = [ "networkmanager" "wheel" ];
              packages = with pkgs; [];
            };
        
            environment.systemPackages = with pkgs; [
              vim
              git
              curl
            ];
            
            nix.package = pkgs.nix;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            nixpkgs.config.allowUnfree = true;
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
      nixosConfigurations.murph = nixpkgs.lib.nixosSystem {
        modules = [ nixosModules.murphHardware ];
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

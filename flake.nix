{
  description = "Are these your dotfiles, Larry?";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      emacs-overlay,
      flake-utils
    }:
    rec {
      nixosModules = rec {
        personal =
          { lib, ... }:
          {
            options.personal = lib.mkOption {
              type = lib.types.attrs;
              default = {
                userName = "jackson";
                fullName = "Jackson Brough";
                email = "jacksontbrough@gmail.com";
              };
            };
          };
        packageManager =
          { pkgs, ... }:
          {
            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];
            nixpkgs.config.allowUnfree = true;
          };
        murphHardware =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          {
            hardware.enableRedistributableFirmware = lib.mkDefault true;
            hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

            nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

            system.stateVersion = "25.05";

            boot = {
              initrd.availableKernelModules = [
                "nvme"
                "xhci_pci"
                "thunderbolt"
                "usb_storage"
                "sd_mod"
              ];
              initrd.kernelModules = [ ];
              kernelModules = [ "kvm-amd" ];
              extraModulePackages = [ ];
              loader.systemd-boot.enable = true;
              loader.efi.canTouchEfiVariables = true;
            };

            fileSystems."/" = {
              device = "/dev/disk/by-uuid/fabb1331-c7e1-40fa-8945-800df616f8a4";
              fsType = "ext4";
            };
            fileSystems."/boot" = {
              device = "/dev/disk/by-uuid/C736-93C5";
              fsType = "vfat";
              options = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
            swapDevices = [
              {
                device = "/dev/disk/by-uuid/02b84575-64ce-4ce3-9c9d-608d2281cb09";
              }
            ];

            networking.hostName = "murph";
            networking.networkmanager.enable = true;
            networking.useDHCP = lib.mkDefault true;

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

            services.xserver.xkb = {
              layout = "us";
              variant = "";
            };

            time.timeZone = "America/Denver";
          };
        userLinux =
          { config, pkgs, ... }:
          {
            nix.settings.trusted-users = [
              "root"
              config.personal.userName
            ];

            environment.systemPackages = with pkgs; [
              curl
              git
              neovim
            ];
            environment.shells = with pkgs; [
              bashInteractive
              fish
            ];

            programs.fish.enable = true;

            users.users.${config.personal.userName} = {
              isNormalUser = true;
              description = config.personal.fullName;
              extraGroups = [
                "networkmanager"
                "wheel"
                "video"
                "input"
              ];
              shell = pkgs.fish;
            };

            services.openssh.enable = true;
          };
        docker =
          { config, pkgs, ... }:
          {
            virtualisation.docker.enable = true;

            users.users.${config.personal.userName}.extraGroups = [ "docker" ];
          };
        defaultDirectories =
          { config, lib, ... }:
          {
            options =
              let
                homeDirectory = "/home/${config.personal.userName}";
              in
              {
                defaultDirectories.repositoriesDirectory = lib.mkOption {
                  type = lib.types.str;
                  default = "${homeDirectory}/repositories";
                };
                defaultDirectories.localDirectory = lib.mkOption {
                  type = lib.types.str;
                  default = "${homeDirectory}/local";
                };
                defaultDirectories.scratchDirectory = lib.mkOption {
                  type = lib.types.str;
                  default = "${homeDirectory}/scratch";
                };
                defaultDirectories.shareDirectory = lib.mkOption {
                  type = lib.types.str;
                  default = "${homeDirectory}/share";
                };
              };
          };
        homeLinux =
          { config, pkgs, ... }:
          {
            imports = [ defaultDirectories ];

            config = {
              home-manager.users.${config.personal.userName} =
                let
                  homeDirectory = "/home/${config.personal.userName}";
                in
                {
                  home.stateVersion = "25.05";
                  programs.home-manager.enable = true;
                  home.homeDirectory = homeDirectory;

                  xdg = {
                    enable = true;
                    cacheHome = "${homeDirectory}/.cache";
                    configHome = "${homeDirectory}/.config";
                    dataHome = "${homeDirectory}/.local/share";
                    stateHome = "${homeDirectory}/.local/state";
                    userDirs = {
                      enable = true;
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
                    ispell
                    jq
                    killall
                    lldb
                    ripgrep

                    (pkgs.texlive.combine {
                      inherit (pkgs.texlive) scheme-basic
                        dvisvgm dvipng
                        wrapfig amsmath ulem hyperref capt-of
                        bussproofs simplebnf tabularray mathtools pgf tikz-cd ninecolors;
                    })
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

                  programs.ssh = {
                    enable = true;
                    matchBlocks = {
                      "*" = {
                        identityFile = "~/.ssh/id_ed25519";
                        addKeysToAgent = "yes";
                      };
                    };
                  };
                };
            };
          };
        homeLinuxGraphical =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          {
            imports = [ dconf ];

            config = {
              services.pulseaudio.enable = false;
              services.pipewire.enable = true;

              services.displayManager.gdm.enable = true;
              services.desktopManager.gnome.enable = true;
              services.gnome.core-apps.enable = false;
              services.gnome.core-developer-tools.enable = false;
              services.gnome.games.enable = false;
              environment.gnome.excludePackages = with pkgs; [
                gnome-tour
                gnome-user-docs
              ];

              home-manager.users.${config.personal.userName} = {
                home.packages = with pkgs; [
                  claude-code
                  codex
                  codex-acp
                  dconf-editor
                  discord
                  evince
                  firefox
                  gemini-cli
                  julia-mono
                  nautilus
                  nicotine-plus
                  noto-fonts
                  slack
                  spotify
                  strawberry
                  vlc
                ];
                home.sessionVariables.NIXOS_OZONE_WL = "1";

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
                  defaultFonts.monospace = [
                    "JuliaMono"
                    "Noto Sans Mono"
                  ];
                  defaultFonts.sansSerif = [ "Noto Sans" ];
                  defaultFonts.serif = [ "Noto Serif" ];
                };

                programs.ghostty = {
                  enable = true;
                  settings = {
                    theme = "dark:3024 Night,light:3024 Day";
                    font-family = "JuliaMono";
                  };
                };

                programs.zed-editor = {
                  enable = true;
                  userSettings = {
                    vim_mode = true;
                  };
                };

                programs.beets = {
                  enable = true;
                  settings = {
                    directory = "${config.defaultDirectories.shareDirectory}/music";
                    import.move = "yes";
                    plugins = [ "musicbrainz" ];
                  };
                };
              };
            };
          };
        dconf =
          { config, lib, ... }:
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
                  dynamic-workspaces = true;
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
        gh =
          { config, pkgs, ... }:
          {
            home-manager.users.${config.personal.userName} = {
              programs.gh = {
                enable = true;
                settings.git_protocol = "ssh";
              };
            };
          };
        gpg =
          { config, pkgs, ... }:
          {
            home-manager.users.${config.personal.userName} = {
              home.packages = with pkgs; [ pinentry-gnome3 ];

              services.ssh-agent.enable = pkgs.stdenv.isLinux;

              programs.gpg = {
                enable = true;
                homedir =
                  let
                    xdgDataHome = config.home-manager.users.${config.personal.userName}.xdg.dataHome;
                  in
                  "${xdgDataHome}/gnupg";
              };
              services.gpg-agent = {
                enable = pkgs.stdenv.isLinux;
                pinentry.package = pkgs.pinentry-gnome3;
                # https://superuser.com/questions/624343/keep-gnupg-credentials-cached-for-entire-user-session
                defaultCacheTtl = 34560000;
                maxCacheTtl = 34560000;
              };
            };
          };
        gopass =
          { config, pkgs, ... }:
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
        tailscale =
          { config, ... }:
          {
            services.tailscale.enable = true;
            services.tailscale.useRoutingFeatures = "client";
          };
        emacsConfiguration =
          { config, pkgs, ... }:
          {
            nixpkgs.overlays = with emacs-overlay.overlays; [
              emacs
              package
            ];

            home-manager.users.${config.personal.userName} = {
              programs.emacs = {
                enable = true;
                package = pkgs.emacsWithPackagesFromUsePackage {
                  package = pkgs.emacs-unstable-pgtk;
                  config = ./emacs.el;
                  defaultInitFile = true;
                  extraEmacsPackages =
                    epkgs: with epkgs; [
                      treesit-grammars.with-all-grammars
                    ];
                  override =
                    epkgs:
                    epkgs
                    // {
                      lean4-mode = epkgs.trivialBuild rec {
                        pname = "lean4-mode";
                        version = "1";
                        src = pkgs.fetchFromGitHub {
                          owner = "bustercopley";
                          repo = "lean4-mode";
                          rev = "f6166f65ac3a50ba32282ccf2c883d61b5843a2b";
                          sha256 = "sha256-mVZh+rP9IWLs2QiPysIuQ3uNAQsuJ63xgUY5akaJjXc";
                        };
                        propagatedUserEnvPkgs = with epkgs; [
                          dash
                          f
                          flycheck
                          lsp-mode
                          magit-section
                          s
                        ];
                        buildInputs = propagatedUserEnvPkgs;
                        postInstall = ''
                          DATADIR=$out/share/emacs/site-lisp/data
                          mkdir $DATADIR
                          install ./data/abbreviations.json $DATADIR
                        '';
                      };
                      # If we really wanted to do this, we should check the org mode build
                      # org = epkgs.trivialBuild rec {
                      #   pname = "org";
                      #   version = "1";
                      #   src = builtins.fetchGit {
                      #     url = "https://git.tecosaur.net/tec/org-mode.git";
                      #     ref = "dev";
                      #     rev = "f9f909681a051c73c64cc7b030aa54d70bb78f80";
                      #   };
                        # sourceRoot = "lisp";
                        # TODO: Need to include some etc directory
                        # postInstall = ''
                        #   DATADIR=$out/share/emacs/site-lisp/data
                        #   mkdir $DATADIR
                        #   install ./data/abbreviations.json $DATADIR
                        # '';
                      # };
                      # org = epkgs.org.overrideAttrs (old: {
                      #   src = builtins.fetchGit {
                      #     url = "https://git.tecosaur.net/tec/org-mode.git";
                      #     ref = "dev";
                      #     rev = "f9f909681a051c73c64cc7b030aa54d70bb78f80";
                      #   };
                      # });
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
          userLinux
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
      templates.rocq = {
        path = ./templates/rocq;
        description = "Coq template";
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [ nixfmt ];
        };
      });
}

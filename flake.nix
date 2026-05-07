{
  description = "Are these your dotfiles, Larry?";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";

    pi-coding-agent.url = "github:broughjt/pi-coding-agent";
    # pi-coding-agent.url = "path:/home/jackson/repositories/pi-coding-agent";
    pi-coding-agent.inputs.nixpkgs.follows = "nixpkgs";
    pi-coding-agent.inputs.flake-utils.follows = "flake-utils";

    flake-utils.url = "github:numtide/flake-utils";

    llm-agents-nix.url = "github:numtide/llm-agents.nix";
    llm-agents-nix.inputs.nixpkgs.follows = "nixpkgs";

    vaultix.url = "github:milieuim/vaultix";
    vaultix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      emacs-overlay,
      pi-coding-agent,
      flake-utils,
      llm-agents-nix,
      vaultix,
      nixos-raspberrypi,
    }:
    let
      emacsRoot = ./emacs;
      vaultixInput = vaultix;

      emacsSourceFiles =
        pkgs:
        let
          emacsFiles = builtins.sort (a: b: (toString a) < (toString b)) (
            pkgs.lib.filesystem.listFilesRecursive emacsRoot
          );
          emacsElFiles = builtins.filter (file: pkgs.lib.strings.hasSuffix ".el" (toString file)) emacsFiles;
          emacsHomeFiles = builtins.listToAttrs (
            map (file: {
              name = ".emacs.d/${pkgs.lib.strings.removePrefix "${toString emacsRoot}/" (toString file)}";
              value = {
                source = file;
              };
            }) emacsFiles
          );
        in
        {
          inherit emacsFiles emacsElFiles emacsHomeFiles;
          emacsConfigText = builtins.concatStringsSep "\n\n" (map builtins.readFile emacsElFiles);
        };

      configureEmacsPackage =
        pkgs:
        let
          emacsSources = emacsSourceFiles pkgs;
        in
        pkgs.emacsWithPackagesFromUsePackage {
          package = pkgs.emacs-git-pgtk;
          config = emacsSources.emacsConfigText;
          defaultInitFile = false;
          override = final: _prev: {
            pi-coding-agent = pi-coding-agent.lib.mkPackage pkgs final;
          };
          extraEmacsPackages =
            epkgs: with epkgs; [
              ghostel
              pi-coding-agent
              treesit-grammars.with-all-grammars
            ];

          alwaysEnsure = true;
        };

      piWebAccessPackage =
        pkgs:
        pkgs.buildNpmPackage rec {
          pname = "pi-web-access";
          version = "0.10.7";

          src = pkgs.fetchFromGitHub {
            owner = "nicobailon";
            repo = "pi-web-access";
            rev = "v${version}";
            hash = "sha256-D9no4SLigH/t3/WfirixMbTEjcEwZwJXld8j7pwBCew=";
          };

          npmDepsHash = "sha256-QKmgVmIvqLbqnUmKBKniT0CvNIgZWZ9mUkha0LJMMVQ=";
          dontNpmBuild = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r package.json README.md CHANGELOG.md *.ts skills node_modules $out/
            runHook postInstall
          '';
        };

      piWebMinimalPackage =
        pkgs:
        pkgs.buildNpmPackage rec {
          pname = "pi-web-minimal";
          version = "0.4.0";

          src = pkgs.fetchFromGitHub {
            owner = "drsh4dow";
            repo = "pi-web-minimal";
            rev = "2927328def03d8b908a3f7e1b64e524434aa2ff7";
            hash = "sha256-RpUi4y3WhCpliFfim7G2xryCEuf+eV0sy0mVMdVT80c=";
          };

          npmDepsHash = "sha256-6rV/tLQR5SKd9zqnJ+DACSYfTzTYqzFDdnxmonxRVvk=";
          postPatch = ''
            cp ${./pi/pi-web-minimal-package-lock.json} package-lock.json
          '';
          npmInstallFlags = [ "--omit=dev" ];
          dontNpmBuild = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r package.json README.md index.ts extensions lib node_modules $out/
            runHook postInstall
          '';
        };

      piSystemPromptPackage =
        pkgs:
        pkgs.stdenvNoCC.mkDerivation rec {
          pname = "pi-system-prompt";
          version = "0.1.2";

          src = pkgs.fetchFromGitHub {
            owner = "jandrikus";
            repo = "pi-system-prompt";
            rev = "554623e9c913f866d3bc94d3a2620d26a1feded7";
            hash = "sha256-zLLF0IlSqoQtSEebEq2t5kInq7mQDjhwUIB5jLwpXyA=";
          };

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r package.json README.md LICENSE extensions $out/
            runHook postInstall
          '';
        };
    in
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
                sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGwFAXp70zd8VHaNEmQ+txSDFCZENuY4yNReGMVyVM61 jacksontbrough@gmail.com";
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
            nix.settings.substituters = [
              "https://cache.numtide.com"
              "https://cache.nixos.org"
              "https://nix-community.cachix.org"
            ];
            nix.settings.trusted-public-keys = [
              "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];
            nixpkgs.overlays = [
              llm-agents-nix.overlays.default
            ];
            nixpkgs.config.allowUnfree = true;
          };
        tarsHardware =
          { lib, nixos-raspberrypi, ... }:
          {
            imports = with nixos-raspberrypi.nixosModules; [
              raspberry-pi-5.base
              raspberry-pi-5.page-size-16k
            ];

            networking.hostName = "tars";
            networking.useDHCP = lib.mkDefault true;

            boot.loader.raspberry-pi.bootloader = "kernel";
            boot.supportedFilesystems.zfs = lib.mkForce false;

            fileSystems."/" = {
              device = lib.mkDefault "/dev/disk/by-label/NIXOS_SD";
              fsType = lib.mkDefault "ext4";
              options = lib.mkForce [
                "x-initrd.mount"
                "noatime"
              ];
            };

            fileSystems."/boot/firmware" = {
              device = lib.mkDefault "/dev/disk/by-label/FIRMWARE";
              fsType = lib.mkDefault "vfat";
              options = lib.mkDefault [
                "noatime"
                "noauto"
                "x-systemd.automount"
                "x-systemd.idle-timeout=1min"
              ];
            };

            system.stateVersion = "25.11";
          };
        tarsAccess =
          { config, ... }:
          {
            users.users.${config.personal.userName}.openssh.authorizedKeys.keys = [
              config.personal.sshPublicKey
            ];
            users.users.root.openssh.authorizedKeys.keys = [ config.personal.sshPublicKey ];

            security.sudo.wheelNeedsPassword = false;
          };
        tarsBase = {
          imports = [
            tarsHardware
            packageManager
            userLinux
            home-manager.nixosModules.home-manager
            personal
            homeLinux
            tarsAccess
          ];
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

            services.fprintd.enable = true;

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

            nix.optimise.automatic = true;
            nix.gc = {
              automatic = true;
              dates = "weekly";
              options = "--delete-older-than 30d";
            };
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
                defaultDirectories.homeDirectory = lib.mkOption {
                  type = lib.types.str;
                  default = homeDirectory;
                };
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
              home-manager.useGlobalPkgs = true;
              home-manager.users.${config.personal.userName} =
                let
                  homeDirectory = config.defaultDirectories.homeDirectory;
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
                    tmux
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
              security.rtkit.enable = true;
              services.pipewire = {
                enable = true;
                alsa.enable = true;
                alsa.support32Bit = true;
                pulse.enable = true;
              };

              services.displayManager.gdm.enable = true;
              services.desktopManager.gnome.enable = true;
              services.gnome.core-apps.enable = false;
              services.gnome.core-developer-tools.enable = false;
              services.gnome.games.enable = false;
              environment.gnome.excludePackages = with pkgs; [
                gnome-tour
                gnome-user-docs
              ];

              xdg.portal = {
                enable = true;
                extraPortals = with pkgs; [
                  xdg-desktop-portal-gtk
                  xdg-desktop-portal-gnome
                ];
                config.common.default = [ "gnome" ];
              };

              home-manager.users.${config.personal.userName} = {
                home.packages = with pkgs; [
                  bubblewrap
                  dconf-editor
                  discord
                  evince
                  firefox
                  hunspell
                  hunspellDicts.en_US
                  julia-mono
                  llm-agents.claude-code
                  llm-agents.claude-agent-acp
                  llm-agents.codex
                  llm-agents.codex-acp
                  llm-agents.gemini-cli
                  llm-agents.opencode
                  llm-agents.pi
                  nautilus
                  nicotine-plus
                  noto-fonts
                  slack
                  spotify
                  strawberry
                  vlc
                  wl-clipboard
                ];
                home.sessionVariables.NIXOS_OZONE_WL = "1";

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
        pass =
          { config, ... }:
          {
            home-manager.users.${config.personal.userName} = {
              programs.password-store = {
                enable = true;
                settings = {
                  PASSWORD_STORE_DIR = "${config.defaultDirectories.repositoriesDirectory}/passwords";
                };
              };
            };
          };
        vaultixConfiguration =
          { config, lib, ... }:
          let
            user = config.personal.userName;
            group = "users";
            homeDirectory = config.defaultDirectories.homeDirectory;
            secretsDirectory = ./secrets;
            exaApiKeySecret = secretsDirectory + "/exa-api-key.age";
            context7ApiKeySecret = secretsDirectory + "/context7-api-key.age";
            exaApiKeyAvailable = builtins.pathExists exaApiKeySecret;
            context7ApiKeyAvailable = builtins.pathExists context7ApiKeySecret;
            piWebSearchSecretsAvailable = exaApiKeyAvailable || context7ApiKeyAvailable;
          in
          {
            imports = [ vaultixInput.nixosModules.default ];

            # Vaultix requires either systemd.sysusers or services.userborn. This config has a
            # normal user, so use userborn rather than systemd.sysusers.
            services.userborn.enable = true;

            vaultix.settings.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJaEBK0rIuwE7GqwgeWKA/DvBxIXOcAMDhiORaK9OSf root@murph";

            vaultix.secrets =
              lib.optionalAttrs exaApiKeyAvailable {
                exaApiKey.file = exaApiKeySecret;
              }
              // lib.optionalAttrs context7ApiKeyAvailable {
                context7ApiKey.file = context7ApiKeySecret;
              };

            vaultix.templates = lib.optionalAttrs piWebSearchSecretsAvailable {
              pi-web-search-json = {
                name = "pi-web-search.json";
                owner = user;
                inherit group;
                mode = "0600";
                content = builtins.toJSON (
                  {
                    provider = "auto";
                    workflow = "none";
                    allowBrowserCookies = false;
                  }
                  // lib.optionalAttrs exaApiKeyAvailable {
                    exaApiKey = config.vaultix.placeholder.exaApiKey;
                  }
                  // lib.optionalAttrs context7ApiKeyAvailable {
                    context7ApiKey = config.vaultix.placeholder.context7ApiKey;
                  }
                );
              };
            };

            systemd.tmpfiles.rules = [
              "d ${homeDirectory}/.pi 0700 ${user} ${group} -"
            ]
            ++ lib.optionals piWebSearchSecretsAvailable [
              "L+ ${homeDirectory}/.pi/web-search.json - - - - ${config.vaultix.templates.pi-web-search-json.path}"
            ];
          };
        piConfiguration =
          { config, pkgs, ... }:
          let
            piWebAccess = piWebAccessPackage pkgs;
            piWebMinimal = piWebMinimalPackage pkgs;
            piSystemPrompt = piSystemPromptPackage pkgs;
          in
          {
            home-manager.users.${config.personal.userName} = {
              home.file.".pi/agent/AGENTS.md" = {
                source = ./pi/AGENTS.md;
                force = true;
              };

              home.file.".pi/agent/bin/npm-nix" = {
                executable = true;
                force = true;
                text = ''
                  #!/usr/bin/env bash
                  set -euo pipefail
                  export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.pi/agent/npm-global}"
                  mkdir -p "$NPM_CONFIG_PREFIX"
                  exec ${pkgs.nodejs}/bin/npm "$@"
                '';
              };

              home.file.".pi/agent/settings.json" = {
                force = true;
                text = builtins.toJSON {
                  defaultProvider = "openai-codex";
                  defaultModel = "gpt-5.5";
                  defaultThinkingLevel = "high";
                  enableInstallTelemetry = false;
                  npmCommand = [ "${config.defaultDirectories.homeDirectory}/.pi/agent/bin/npm-nix" ];
                  packages = [
                    # {
                    #   source = "${piWebAccess}";
                    #   extensions = [];
                    #   skills = [];
                    # }
                    "${piWebMinimal}"
                  ];
                };
              };
            };
          };
        kakouneConfiguration =
          { config, pkgs, ... }:
          {
            home-manager.users.${config.personal.userName} = {
              home.packages = with pkgs; [
                kakoune-lsp
              ];

              programs.kakoune = {
                enable = true;
                colorSchemePackage = pkgs.writeText "ibm-5153-cga-black.kak" ''
                  set-face global Default rgb:c4c4c4,rgb:000000
                  set-face global PrimarySelection rgb:000000,rgb:c4c4c4
                  set-face global SecondarySelection rgb:000000,rgb:4e4e4e
                  set-face global PrimaryCursor rgb:000000,rgb:c4c4c4+b
                  set-face global SecondaryCursor rgb:000000,rgb:4e4e4e+b
                  set-face global LineNumbers rgb:4e4e4e,rgb:000000
                  set-face global LineNumberCursor rgb:ffffff,rgb:000000+b
                  set-face global MenuForeground rgb:000000,rgb:c4c4c4
                  set-face global MenuBackground rgb:c4c4c4,rgb:000000
                  set-face global MenuInfo rgb:4ef3f3,rgb:000000
                  set-face global Information rgb:000000,rgb:4ef3f3
                  set-face global Error rgb:000000,rgb:dc4e4e
                  set-face global DiagnosticError rgb:dc4e4e,rgb:000000
                  set-face global DiagnosticWarning rgb:f3f34e,rgb:000000
                  set-face global DiagnosticHint rgb:4ef3f3,rgb:000000
                  set-face global DiagnosticInfo rgb:4e4edc,rgb:000000
                  set-face global StatusLine rgb:000000,rgb:c4c4c4
                  set-face global StatusLineMode rgb:000000,rgb:f3f34e+b
                  set-face global StatusLineInfo rgb:000000,rgb:4ef3f3
                  set-face global StatusLineValue rgb:000000,rgb:4edc4e
                  set-face global StatusCursor rgb:000000,rgb:c4c4c4
                  set-face global Prompt rgb:000000,rgb:c4c4c4+b
                  set-face global MatchingChar rgb:000000,rgb:f3f34e
                  set-face global Search rgb:000000,rgb:f3f34e
                  set-face global Whitespace rgb:4e4e4e,rgb:000000
                  set-face global BufferPadding rgb:4e4e4e,rgb:000000

                  set-face global value rgb:4edc4e,rgb:000000
                  set-face global type rgb:4ef3f3,rgb:000000
                  set-face global variable rgb:c4c4c4,rgb:000000
                  set-face global module rgb:4e4edc,rgb:000000
                  set-face global function rgb:f34ef3,rgb:000000
                  set-face global string rgb:4edc4e,rgb:000000
                  set-face global keyword rgb:dc4e4e,rgb:000000+b
                  set-face global operator rgb:f3f34e,rgb:000000
                  set-face global attribute rgb:4ef3f3,rgb:000000
                  set-face global comment rgb:4e4e4e,rgb:000000+i
                  set-face global documentation rgb:4e4e4e,rgb:000000+i
                  set-face global meta rgb:c47e00,rgb:000000
                  set-face global builtin rgb:4e4edc,rgb:000000+b

                  set-face global title rgb:4e4edc,rgb:000000+b
                  set-face global header rgb:f34ef3,rgb:000000+b
                  set-face global mono rgb:4edc4e,rgb:000000
                  set-face global block rgb:c4c4c4,rgb:4e4e4e
                  set-face global link rgb:4ef3f3,rgb:000000+u
                  set-face global bullet rgb:dc4e4e,rgb:000000
                  set-face global list rgb:c4c4c4,rgb:000000
                '';
                config.colorScheme = "ibm-5153-cga-black";
                extraConfig = ''
                  eval %sh{kak-lsp}
                  lsp-enable

                  map global user l ':enter-user-mode lsp<ret>' -docstring 'LSP mode'

                  map global goto d <esc>:lsp-definition<ret> -docstring 'LSP definition'
                  map global goto r <esc>:lsp-references<ret> -docstring 'LSP references'
                  map global goto y <esc>:lsp-type-definition<ret> -docstring 'LSP type definition'

                  map global insert <tab> '<a-;>:try lsp-snippets-select-next-placeholders catch %{ execute-keys -with-hooks <lt>tab> }<ret>' -docstring 'Select next snippet placeholder'

                  map global object a '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
                  map global object <a-a> '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
                  map global object f '<a-semicolon>lsp-object Function Method<ret>' -docstring 'LSP function or method'
                  map global object t '<a-semicolon>lsp-object Class Interface Module Namespace Struct<ret>' -docstring 'LSP class or module'
                  map global object d '<a-semicolon>lsp-diagnostic-object error warning<ret>' -docstring 'LSP errors and warnings'
                  map global object D '<a-semicolon>lsp-diagnostic-object error<ret>' -docstring 'LSP errors'
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
          let
            emacsData = emacsSourceFiles pkgs;
          in
          {
            nixpkgs.overlays = with emacs-overlay.overlays; [
              emacs
              package
            ];

            home-manager.users.${config.personal.userName} = {
              programs.emacs = {
                enable = true;
                package = configureEmacsPackage pkgs;
              };
              home.file = emacsData.emacsHomeFiles;
              services.emacs = {
                enable = pkgs.stdenv.isLinux;
                package = config.home-manager.users.${config.personal.userName}.programs.emacs.package;
                defaultEditor = true;
              };
            };
          };
      };
      nixosConfigurations.murph = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs self;
        };
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
          pass
          vaultixConfiguration
          piConfiguration
          kakouneConfiguration
          emacsConfiguration
        ];
      };
      nixosConfigurations.tars = nixos-raspberrypi.lib.nixosSystem {
        inherit nixpkgs;
        specialArgs = inputs;
        modules = [ nixosModules.tarsBase ];
      };
      vaultix = vaultixInput.configure {
        nodes = {
          inherit (self.nixosConfigurations) murph;
        };
        # String path, not a Nix path literal: keeps the private key out of the Nix store.
        identity = "/home/jackson/.ssh/id_ed25519";
        cache = "./secrets/cache";
        defaultSecretDirectory = "./secrets";
        systems = [
          "x86_64-linux"
          "aarch64-linux"
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
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            llm-agents-nix.overlays.default
          ]
          ++ (with emacs-overlay.overlays; [
            emacs
            package
          ]);
          config.allowUnfree = true;
        };
        emacsPackage = configureEmacsPackage pkgs;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nil
            nixfmt
          ];
        };
        checks.emacs-byte-compile = pkgs.runCommand "emacs-byte-compile-check" { src = ./.; } ''
          cp -r "$src/emacs" .
          chmod -R u+w emacs
          HOME="$TMPDIR" ${emacsPackage}/bin/emacs --batch \
            -L emacs -L emacs/modules -L emacs/modules/languages \
            --eval "(setq byte-compile-error-on-warn t)" \
            -f batch-byte-compile \
            emacs/init.el emacs/modules/*.el emacs/modules/languages/*.el
          mkdir -p "$out"
        '';
      }
    );
}

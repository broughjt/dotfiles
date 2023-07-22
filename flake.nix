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
  };

  outputs = { nixpkgs, home-manager, emacs-overlay, ... }:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      # TODO: I'm confused, nixpkgs doesn't look like a function in it's flake.nix
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = with emacs-overlay.overlays; [ emacs package ];
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
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
      nixosConfigurations.murph = lib.nixosSystem {
        inherit system;
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

              nixpkgs.config.allowUnfree = true;

              environment.systemPackages = with pkgs; [
                busybox
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
      homeConfigurations.jackson = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ({ config, pkgs, ... }:

            let
              userName = "jackson";
              email = "jacksontbrough@gmail.com";
              homeDirectory = "/home/${userName}";
              repositoriesDirectory = "${homeDirectory}/repositories";
              sharedDirectory = "${homeDirectory}/shared";
              localDirectory = "${homeDirectory}/local";
              scratchDirectory = "${localDirectory}/scratch";
              emacs = (pkgs.emacsWithPackagesFromUsePackage {
                config = ./emacs.el;
                defaultInitFile = true;
                package = pkgs.emacs-unstable-pgtk;
                alwaysEnsure = true;
              });
              # https://nixos.wiki/wiki/Slack
              # https://wiki.archlinux.org/title/wayland
              # TODO: Screen sharing
              slack = pkgs.slack.overrideAttrs (previous: {
                installPhase = previous.installPhase + ''
                  rm $out/bin/slack

                  makeWrapper $out/lib/slack/slack $out/bin/slack \
                    --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
                    --prefix PATH : ${lib.makeBinPath [pkgs.xdg-utils]} \
                    --add-flags "--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-webrtc-pipewire-capturer"
                '';
              });
            in {
              home.username = userName;
              home.homeDirectory = homeDirectory;
              home.stateVersion = "23.05";
              home.packages = with pkgs; [
                exa
                killall
                ripgrep
                
                gopass
                pinentry-gnome
                
                jetbrains-mono
                source-sans
                source-serif
                
                # TODO: zoom
                # TODO: obsidian
                slack
                spotify
              ];

              programs.home-manager.enable = true;

              xdg.enable = true;
              xdg.cacheHome = "${homeDirectory}/.cache";
              xdg.configHome = "${homeDirectory}/.config";
              xdg.dataHome = "${homeDirectory}/.local/share";
              xdg.stateHome = "${homeDirectory}/.local/state";
              xdg.userDirs = {
                createDirectories = true;
                documents = scratchDirectory;
                download = scratchDirectory;
                music = "${sharedDirectory}/music";
                pictures = "${sharedDirectory}/pictures";
                publicShare = scratchDirectory;
                templates = scratchDirectory;
                videos = "${sharedDirectory}/videos";
              };

              fonts.fontconfig.enable = true;

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
                pinentryFlavor = "gnome3";
              };

              xdg.configFile.gopass = {
                target = "gopass/config";
                text = ''
                  [mounts]
                      path = ${repositoriesDirectory}/passwords
                  [recipients]
                      hash = c9903be2bdd11ffec04509345292bfa567e6b28e7e6aa866933254c5d1344326
                '';
              };

              programs.direnv.enable = true;

              gtk = {
                enable = true;
                font.name = "Source Sans";
                theme = { name = "WhiteSur"; package = pkgs.whitesur-gtk-theme; };
                iconTheme = { name = "WhiteSur"; package = pkgs.whitesur-icon-theme; };
              };
              # TODO: https://github.com/pop-os/shell
              # TODO: https://the-empire.systems/nixos-gnome-settings-and-keyboard-shortcuts
              # TODO: https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/
              # TODO: playerctl
              dconf.settings = {
                # TODO
                "org/gnome/desktop/background" = { picture-uri = "file://${config.xdg.userDirs.pictures}/cosmic-cliffs.png"; };
                "org/gnome/desktop/interface" = {
                  clock-format = "12h";
                  color-scheme = "prefer-dark";
                  enable-hot-corners = false;
                  # TODO
                  # font-antialiasing = "grayscale";
                  # font-hinting = "slight";
                  # gtk-theme = "Nordic";
                  # toolkit-accessibility = true;
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

              programs.emacs = {
                enable = true;
                package = emacs;
              };
              services.emacs = {
                enable = true;
                package = emacs;
                startWithUserSession = "graphical";
                defaultEditor = true;
              };
            })
        ];
      };
    };
}

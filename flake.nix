{
  description = "Are these your configuration files, Larry?";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
  };

  outputs = { nixpkgs, home-manager, emacs-overlay, ... }:
    let
      inherit (nixpkgs) lib;
      # TODO: Use flake-utils to make this generic? (For kenobi)
      system = "x86_64-linux";
      # TODO: I'm confused, nixpkgs doesn't look like a function in it's flake.nix
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = with emacs-overlay.overlays; [ emacs package ];
      };
    in
    {
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

              networking.hostName = "murph";
              networking.networkmanager.enable = true;

              # TODO: What is this needed for?
              security.polkit.enable = true;

	            # TODO: Gnome didn't like pipewire
	            /*
              security.rtkit.enable = true;
              services.pipewire = {
                enable = true;
                alsa.enable = true;
                alsa.support32Bit = true;
                pulse.enable = true;
              };
              hardware.bluetooth.enable = true;
              services.blueman.enable = true;
              # TODO: Magical bluetooth incantations
              environment.etc = {
                "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
                  bluez_monitor.properties = {
                    ["bluez5.enable-sbc-xq"] = true,
                    ["bluez5.enable-msbc"] = true,
                    ["bluez5.enable-hw-volume"] = true,
                    ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
                  }
                '';
              };
	            */

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
                open = true;
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

              # Prevent a world of pain where nix 2.4 has you fetching rocks for
              # a long time until you finally discover that it wanted git but
              # refused to tell you.
              environment.systemPackages = with pkgs; [ curl git neovim ];

              programs.fish.enable = true;

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
          # TODO: hyprland.homeManagerModules.default
          ({ config, pkgs, ... }:

            let
              # TODO: Other duplicated stuff goes here
              userName = "jackson";
              email = "jacksontbrough@gmail.com";
              emacs = (pkgs.emacsWithPackagesFromUsePackage {
                config = ./emacs.el;
                defaultInitFile = true;
                package = pkgs.emacs-unstable-pgtk;
                alwaysEnsure = true;
              });
            in {
              home.username = userName;
              home.homeDirectory = "/home/${userName}";

              home.stateVersion = "23.05";

              programs.home-manager.enable = true;

              home.packages = with pkgs; [
                ripgrep
                exa
                killall

                jetbrains-mono
                source-sans
                source-serif

                gopass
                pinentry-gnome

                spotify
              ];

              fonts.fontconfig.enable = true;

              programs.fish.enable = true;

              programs.git = {
                enable = true;
                userEmail = email;
              };

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
                      path = /home/jackson/repositories/passwords
                  [recipients]
                      hash = c9903be2bdd11ffec04509345292bfa567e6b28e7e6aa866933254c5d1344326
                '';
              };

              programs.alacritty = {
                enable = true;
                settings = {
                  font.normal = { family = "JetBrains Mono"; style = "Regular"; };
                  font.size = 12;
                };
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

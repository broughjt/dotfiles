{
  description = "Are these your configuration files, Larry?";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # hyprland.url = "github:hyprwm/Hyprland";

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
        overlays = [emacs-overlay.overlays.emacs emacs-overlay.overlays.package];
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

	      # TODO:
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
  		gnome-music
  		gnome-terminal
  		gedit
  		epiphany
  		geary
  		evince
  		gnome-characters
  		totem
  		tali
  		iagno
  		hitori
  		atomix
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

              # Prevent a world of pain where the nix tool has you fetching rocks 
              # for a long time until you finally discover that it wants git but refuses 
              # to tell you that.
              environment.systemPackages = with pkgs; [ curl git neovim ];

              programs.fish.enable = true;
              # TODO: Does this actually help
              # programs.light.enable = true;

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
              emacs = (pkgs.emacsWithPackagesFromUsePackage {
                config = ./emacs.el;
                defaultInitFile = true;
                package = pkgs.emacs-unstable-pgtk;
                alwaysEnsure = true;
              });
            in {
              home.username = userName;
              home.homeDirectory = "/home/jackson";

              home.stateVersion = "23.05";

              # home.sessionVariables = {
              #   # Magic wayland incantations
              #   LIBVA_DRIVER_NAME = "nvidia";
              #   XDG_SESSION_TYPE = "wayland";
              #   GBM_BACKEND = "nvidia-drm";
              #   __GLX_VENDOR_LIBRARY_NAME = "nvidia";
              #   WLR_NO_HARDWARE_CURSORS = "1";
              #   MOZ_ENABLE_WAYLAND = "1";
              # };

              home.packages = with pkgs; [
                ripgrep
                exa
                killall

                jetbrains-mono
                source-sans
                source-serif

                gopass
                pinentry-gnome
                # swaybg

                spotify
              ];

              fonts.fontconfig.enable = true;

              programs.home-manager.enable = true;

              programs.fish.enable = true;

              programs.git = {
                enable = true;
                userName = "Jackson Brough";
                userEmail = "jacksontbrough@gmail.com";
              };

              programs.ssh = {
                enable = true;
              };
              services.ssh-agent.enable = true;

              programs.gpg = {
                enable = true;
                homedir = "${config.xdg.dataHome}/gnupg";
              };
              services.gpg-agent = {
                enable = true;
                pinentryFlavor = "gnome3";
                # TODO: Surely there's something I don't understand about derivations and 
                # there's a way to do this without the hack
                # extraConfig = "pinentry-program ${pkgs.pinentry-rofi.out}/bin/pinentry-rofi";
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

              # TODO: Download nasa wallpaper and output in some pictures directory
	      /*
              wayland.windowManager.hyprland = {
                enable = true;
                extraConfig = ''
                exec-once = waybar
                # TODO: Remove
                exec-once = swaybg -i ~/cosmic-cliffs.png

                windowrule = workspace 1 silent, emacs
                exec-once = emacsclient -c

                monitor = ,preferred,auto,auto

                env = XCURSOR_SIZE,24
                input {
                    kb_layout = us
                    kb_variant =
                    kb_model =
                    kb_options =
                    kb_rules =
                
                    follow_mouse = 1
                
                    touchpad {
                        natural_scroll = yes
                    }

                    sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
                }

                general {
                    gaps_in = 5
                    gaps_out = 20
                    border_size = 2
                    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
                    col.inactive_border = rgba(595959aa)

                    layout = dwindle
                }

                decoration {
                    rounding = 10
                    blur = yes
                    blur_size = 3
                    blur_passes = 1
                    blur_new_optimizations = on

                    drop_shadow = yes
                    shadow_range = 4
                    shadow_render_power = 3
                    col.shadow = rgba(1a1a1aee)
                }

                animations {
                    enabled = yes

                    bezier = myBezier, 0.05, 0.9, 0.1, 1.05

                    animation = windows, 1, 7, myBezier
                    animation = windowsOut, 1, 7, default, popin 80%
                    animation = border, 1, 10, default
                    animation = borderangle, 1, 8, default
                    animation = fade, 1, 7, default
                    animation = workspaces, 1, 6, default
                }

                dwindle {
                    pseudotile = yes
                    preserve_split = yes
                    no_gaps_when_only = yes
                }

                master {
                    new_is_master = true
                }

                gestures {
                    workspace_swipe = on
                }

                $modifier = SUPER

                bind = $modifier SHIFT, Q, exit,
                bind = $modifier, Q, killactive,
                bind = $modifier, Return, exec, alacritty
                bind = $modifier, D, exec, rofi -show run
                bind = $modifier, V, togglefloating

                bind = $modifier, H, movefocus, l
                bind = $modifier, J, movefocus, r
                bind = $modifier, K, movefocus, u
                bind = $modifier, L, movefocus, d
                
                bind = $modifier, 1, workspace, 1
                bind = $modifier, 2, workspace, 2
                bind = $modifier, 3, workspace, 3
                bind = $modifier, 4, workspace, 4
                bind = $modifier, 5, workspace, 5
                bind = $modifier, 6, workspace, 6
                bind = $modifier, 7, workspace, 7
                bind = $modifier, 8, workspace, 8
                bind = $modifier, 9, workspace, 9  
                bind = $modifier, 0, workspace, 10
                
                bind = $modifier SHIFT, 1, movetoworkspace, 1
                bind = $modifier SHIFT, 2, movetoworkspace, 2
                bind = $modifier SHIFT, 3, movetoworkspace, 3
                bind = $modifier SHIFT, 4, movetoworkspace, 4
                bind = $modifier SHIFT, 5, movetoworkspace, 5
                bind = $modifier SHIFT, 6, movetoworkspace, 6
                bind = $modifier SHIFT, 7, movetoworkspace, 7
                bind = $modifier SHIFT, 8, movetoworkspace, 8
                bind = $modifier SHIFT, 9, movetoworkspace, 9
                bind = $modifier SHIFT, 0, movetoworkspace, 10

                # TODO: Can we get rid of 272 and 273?
                bind = $modifier, mouse:272, movewindow
                bind = $modifier, mouse:273, resizewindowpixel

                bindsym MonBrightnessDown exec light -U 10
                bindsym MonBrightnessUp exec light -A 10

                bindsym AudioRaiseVolume exec 'wpctl set-volume @DEFAULT_SINK@ 5%+'
                bindsym AudioLowerVolume exec 'wpctl set-volume @DEFAULT_SINK@ 5%-'
                bindsym AudioMute exec 'wpctl set-mute @DEFAULT_SINK@ toggle'
                '';
              };
	      */

              /*
              programs.waybar = {
                enable = true;
                settings = {
                  mainBar = {
                    layer = "top";
                    position = "top";
                    height = 30;
                    spacing = 4;
                    modules-left = ["hyprland/workspaces"];
                    modules-right = ["bluetooth" "network" "pulseaudio" "battery" "clock"];
                  };
                };
              };
	      */

	      /*
              programs.rofi = {
                enable = true;
                package = pkgs.rofi-wayland;
                pass.enable = true;
                pass.stores = [ "/home/jackson/repositories/passwords" ];
              };
	      */

              programs.alacritty = {
                enable = true;
                settings = {
                  font.normal = { family = "JetBrains Mono"; style = "Regular"; };
                  font.size = 12;
                };
              };

              programs.firefox = {
                enable = true;
		# TODO: true
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

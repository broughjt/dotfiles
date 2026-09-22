{
  description = "Are these your dotfiles, Larry?";

  # Nix requires `nixConfig` values to be literal, so these cannot be imported from
  # `./nix/nix-config.nix`. Keep them in sync with the cache definitions there.
  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url = "github:nix-community/impermanence";

    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.inputs.disko.follows = "disko";

    flake-utils.url = "github:numtide/flake-utils";

    llm-agents-nix.url = "github:numtide/llm-agents.nix";

    # Not following our nixpkgs: the vendor kernel and ZFS module are only in
    # nixos-raspberrypi's binary cache when built against its own pin.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

    # For hosts built on nixos-raspberrypi's nixpkgs pin, which is a release
    # branch rather than our unstable.
    home-manager-raspberrypi.url = "github:nix-community/home-manager/release-26.05";
    home-manager-raspberrypi.inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      emacs-overlay,
      disko,
      impermanence,
      nixos-anywhere,
      flake-utils,
      llm-agents-nix,
      nixos-raspberrypi,
      home-manager-raspberrypi,
    }:
    let
      nix-config = import ./nix/nix-config.nix;
      emacsPackages = import ./nix/packages/emacs.nix;
      # Keep llm-agents on its own pinned nixpkgs so its outputs match the
      # derivations built by Numtide's binary cache.
      llmAgentsOverlay = final: _prev: {
        llm-agents = llm-agents-nix.packages.${final.stdenv.hostPlatform.system};
      };
      # emacs-overlay still reads deprecated stdenv platform aliases. Keep the
      # compatibility values local to that overlay until upstream migrates.
      emacsPlatformCompatOverlay =
        final: prev:
        emacs-overlay.overlays.emacs final (
          prev
          // {
            stdenv = prev.stdenv // {
              inherit (prev.stdenv.hostPlatform) isAarch64 isLinux;
            };
          }
        );
      emacsOverlays = [
        emacsPlatformCompatOverlay
        emacs-overlay.overlays.package
      ];
      makePkgsWithOverlays =
        extraOverlays: system:
        import nixpkgs {
          inherit system;
          overlays = [ llmAgentsOverlay ] ++ extraOverlays ++ emacsOverlays;
          config = nix-config.nixpkgsConfig;
        };
      makePkgs = makePkgsWithOverlays [ ];

      nixosModules = import ./nix/modules {
        inherit
          llmAgentsOverlay
          emacsOverlays
          disko
          impermanence
          ;
      };

      nixosConfigurations = {
        murph = import ./nix/hosts/murph.nix {
          inherit
            nixpkgs
            home-manager
            nixosModules
            ;
        };
        case = import ./nix/hosts/case.nix {
          inherit
            nixpkgs
            home-manager
            nixosModules
            ;
        };
        murph-install = import ./nix/hosts/murph-install.nix {
          inherit
            nixpkgs
            home-manager
            nixosModules
            ;
        };
        # ./nix/hosts/tars.nix is the class rather than a configuration; each Pi
        # is a tars<n> instance of it.
        tars1 = import ./nix/hosts/tars1.nix {
          inherit nixos-raspberrypi nixosModules;
          home-manager = home-manager-raspberrypi;
        };
        tars-installer = import ./nix/hosts/tars-installer.nix {
          inherit
            nixos-raspberrypi
            nixosModules
            ;
        };
        kipp = import ./nix/hosts/kipp.nix {
          inherit
            nixpkgs
            home-manager
            nixosModules
            ;
        };
        kipp-installer = import ./nix/hosts/kipp-installer.nix {
          inherit nixpkgs nixosModules;
        };
      };
      darwinConfigurations = {
        s1111508 = import ./nix/hosts/s1111508.nix {
          inherit
            nix-darwin
            home-manager
            nix-config
            emacsOverlays
            nixosModules
            ;
        };
      };
    in
    {
      inherit
        nixosModules
        nixosConfigurations
        darwinConfigurations
        ;

      templates = import ./nix/templates.nix;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = makePkgs system;
        emacsPackage = emacsPackages.configureEmacsPackage pkgs;
        scriptPackages = import ./nix/packages/scripts.nix {
          inherit
            disko
            nixos-anywhere
            pkgs
            self
            system
            ;
        };
        makeScriptApp = package: executable: description: {
          type = "app";
          program = "${package}/bin/${executable}";
          meta = { inherit description; };
        };
        scriptApps = {
          applyTailnetPolicy =
            makeScriptApp scriptPackages.applyTailnetPolicy "apply-tailnet-policy"
              "Apply this repository's tailnet policy file to Tailscale";
          backupMurphSecrets =
            makeScriptApp scriptPackages.backupMurphSecrets "backup-murph-secrets"
              "Back up Murph's persisted SSH and GPG secrets";
          flashNixosInstaller =
            makeScriptApp scriptPackages.flashNixosInstaller "flash-nixos-installer"
              "Download and write a NixOS installer image";
          installCase =
            makeScriptApp scriptPackages.installCase "install-case"
              "Provision a Hetzner Cloud VM and install NixOS on it";
          installKipp =
            makeScriptApp scriptPackages.installKipp "install-kipp"
              "Install NixOS on kipp from its installer stick";
          installMurph = makeScriptApp scriptPackages.installMurph "install-murph" "Install NixOS on Murph";
          installTars =
            makeScriptApp scriptPackages.installTars "install-tars"
              "Install NixOS on tars from its installer image";
          flashKippInstaller =
            makeScriptApp scriptPackages.flashKippInstaller "flash-kipp-installer"
              "Build the kipp installer image and flash it";
          flashTarsBootstrap =
            makeScriptApp scriptPackages.flashTarsBootstrap "flash-tars-bootstrap"
              "Flash Raspberry Pi OS as a bootstrap that builds the tars installer";
          flashTarsInstaller =
            makeScriptApp scriptPackages.flashTarsInstaller "flash-tars-installer"
              "Build the tars installer image on an aarch64 builder and flash it";
          restoreMurphSecrets =
            makeScriptApp scriptPackages.restoreMurphSecrets "restore-murph-secrets"
              "Restore Murph's persisted SSH and GPG secrets";
        };
      in
      (import ./nix/shell.nix { inherit pkgs scriptPackages; })
      // (import ./nix/checks.nix { inherit pkgs emacsPackage; })
      // (import ./nix/formatter.nix { inherit pkgs; })
      // {
        packages = scriptPackages;
        apps = scriptApps;
      }
    );
}

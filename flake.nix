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

    flake-utils.url = "github:numtide/flake-utils";

    llm-agents-nix.url = "github:numtide/llm-agents.nix";
    llm-agents-nix.inputs.nixpkgs.follows = "nixpkgs";
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
      flake-utils,
      llm-agents-nix,
    }:
    let
      nix-config = import ./nix/nix-config.nix;
      emacsPackages = import ./nix/packages/emacs.nix;
      llmAgentsOverlay = llm-agents-nix.overlays.shared-nixpkgs;
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
          backupMurphSecrets =
            makeScriptApp scriptPackages.backupMurphSecrets "backup-murph-secrets"
              "Back up Murph's persisted SSH and GPG secrets";
          flashNixosInstaller =
            makeScriptApp scriptPackages.flashNixosInstaller "flash-nixos-installer"
              "Download and write a NixOS installer image";
          installMurph = makeScriptApp scriptPackages.installMurph "install-murph" "Install NixOS on Murph";
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

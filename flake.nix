{
  description = "Are these your dotfiles, Larry?";

  # Nix requires `nixConfig` values to be literal, so these cannot be imported from
  # `./nix/nix-config.nix`. Keep them in sync with the cache definitions there.
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

    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url = "github:nix-community/impermanence";

    googleworkspace-cli.url = "github:googleworkspace/cli";
    googleworkspace-cli.inputs.nixpkgs.follows = "nixpkgs";
    googleworkspace-cli.inputs.flake-utils.follows = "flake-utils";

    pi-coding-agent.url = "github:broughjt/pi-coding-agent";
    # pi-coding-agent.url = "path:/home/jackson/repositories/pi-coding-agent";
    pi-coding-agent.inputs.nixpkgs.follows = "nixpkgs";
    pi-coding-agent.inputs.flake-utils.follows = "flake-utils";

    flake-utils.url = "github:numtide/flake-utils";

    llm-agents-nix.url = "github:numtide/llm-agents.nix";
    llm-agents-nix.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
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
      googleworkspace-cli,
      pi-coding-agent,
      flake-utils,
      llm-agents-nix,
      agenix,
      nixos-raspberrypi,
    }:
    let
      nix-config = import ./nix/nix-config.nix;
      emacsPackages = import ./nix/packages/emacs.nix { inherit pi-coding-agent; };
      llmAgentsOverlay = llm-agents-nix.overlays.default;
      todoistCliOverlay = final: _prev: {
        todoist-cli = final.callPackage ./nix/packages/todoist-cli.nix { };
        todoist-cli-pi-skill = final.callPackage ./nix/packages/todoist-cli-pi-skill.nix { };
      };
      googleWorkspaceCliOverlay = final: _prev: {
        gws = googleworkspace-cli.packages.${final.stdenv.hostPlatform.system}.default;
      };
      emacsOverlays = with emacs-overlay.overlays; [
        emacs
        package
      ];
      makePkgsWithOverlays =
        extraOverlays: system:
        import nixpkgs {
          inherit system;
          overlays = [ llmAgentsOverlay ] ++ extraOverlays ++ emacsOverlays;
          config = nix-config.nixpkgsConfig;
        };
      makePkgs = makePkgsWithOverlays [
        todoistCliOverlay
        googleWorkspaceCliOverlay
      ];

      piWebMinimalPackage = import ./nix/packages/pi-web-minimal.nix;
      piMcpAdapterPackage = import ./nix/packages/pi-mcp-adapter.nix;
      piSubagentsPackage = import ./nix/packages/pi-subagents.nix;

      nixosModules = import ./nix/modules {
        inherit
          home-manager
          nix-config
          llmAgentsOverlay
          emacsOverlays
          disko
          impermanence
          agenix
          nixos-raspberrypi
          piWebMinimalPackage
          piMcpAdapterPackage
          piSubagentsPackage
          todoistCliOverlay
          googleWorkspaceCliOverlay
          ;
        inherit (emacsPackages) configureEmacsPackage;
      };

      nixosConfigurations = {
        murph = import ./nix/hosts/murph.nix {
          inherit
            inputs
            self
            nixpkgs
            home-manager
            nixosModules
            ;
        };
        murph-install = import ./nix/hosts/murph-install.nix {
          inherit
            inputs
            self
            nixpkgs
            home-manager
            nixosModules
            ;
        };
        tars = import ./nix/hosts/tars.nix {
          inherit
            inputs
            nixpkgs
            nixos-raspberrypi
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
            llmAgentsOverlay
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
        makeScriptApp = package: executable: {
          type = "app";
          program = "${package}/bin/${executable}";
        };
        scriptApps = {
          backupMurphSecrets = makeScriptApp scriptPackages.backupMurphSecrets "backup-murph-secrets";
          flashNixosInstaller = makeScriptApp scriptPackages.flashNixosInstaller "flash-nixos-installer";
          installMurph = makeScriptApp scriptPackages.installMurph "install-murph";
          piPrintSystemPrompt = makeScriptApp scriptPackages.piPrintSystemPrompt "pi-print-system-prompt";
          restoreMurphSecrets = makeScriptApp scriptPackages.restoreMurphSecrets "restore-murph-secrets";
        };
      in
      (import ./nix/shell.nix { inherit pkgs scriptPackages; })
      // (import ./nix/checks.nix { inherit pkgs emacsPackage; })
      // (import ./nix/formatter.nix { inherit pkgs; })
      // {
        packages = scriptPackages // {
          todoist-cli = pkgs.todoist-cli;
          todoist-cli-pi-skill = pkgs.todoist-cli-pi-skill;
          pi-subagents = piSubagentsPackage pkgs;
        };
        apps = scriptApps;
      }
    );
}

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
      vaultixInput = vaultix;
      emacsPackages = import ./nix/packages/emacs.nix { inherit pi-coding-agent; };
      makePkgs = import ./nix/pkgs.nix {
        inherit
          nixpkgs
          emacs-overlay
          llm-agents-nix
          ;
      };

      piWebAccessPackage = import ./nix/packages/pi-web-access.nix;
      piWebMinimalPackage = import ./nix/packages/pi-web-minimal.nix;
      piSystemPromptPackage = import ./nix/packages/pi-system-prompt.nix;

      nixosModules = import ./nix/modules {
        inherit
          home-manager
          emacs-overlay
          llm-agents-nix
          vaultixInput
          nixos-raspberrypi
          piWebAccessPackage
          piWebMinimalPackage
          piSystemPromptPackage
          ;
        inherit (emacsPackages) emacsSourceFiles configureEmacsPackage;
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
        tars = import ./nix/hosts/tars.nix {
          inherit
            inputs
            nixpkgs
            nixos-raspberrypi
            nixosModules
            ;
        };
      };
    in
    {
      inherit nixosModules nixosConfigurations;

      vaultix = vaultixInput.configure {
        nodes = {
          inherit (nixosConfigurations) murph;
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

      templates = import ./nix/templates.nix;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = makePkgs system;
        emacsPackage = emacsPackages.configureEmacsPackage pkgs;
      in
      (import ./nix/shell.nix { inherit pkgs; })
      // (import ./nix/checks.nix { inherit pkgs emacsPackage; })
      // (import ./nix/formatter.nix { inherit pkgs; })
    );
}

{
  description = "Haskell package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        packageName = "haskell-project";
        package = pkgs.haskellPackages.callCabal2nix packageName ./. { };
      in
      {
        packages = {
          default = package;
          ${packageName} = package;
        };

        apps.default = {
          type = "app";
          program = "${package}/bin/${packageName}";
          meta.description = "Run ${packageName}";
        };

        devShells.default = pkgs.haskellPackages.shellFor {
          packages = _: [ package ];

          buildInputs = [
            pkgs.cabal-install
            pkgs.haskell-language-server
            pkgs.fourmolu
            pkgs.hlint
            pkgs.ghcid
          ];
        };
      }
    );
}

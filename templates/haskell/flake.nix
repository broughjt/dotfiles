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
        hs = pkgs.haskellPackages;

        packageName = "haskell-project";

        haskellDeps = hpkgs: [
          hpkgs.base
        ];

        ghcWithDeps = hs.ghcWithPackages haskellDeps;

        package = hs.callPackage
          ({ base, lib }:
            hs.mkDerivation {
              pname = packageName;
              version = "0.1.0.0";
              src = lib.cleanSource ./.;
              isLibrary = false;
              isExecutable = true;
              executableHaskellDepends = [ base ];
              description = "Haskell project";
              license = lib.licenses.bsd3;
              mainProgram = packageName;
            })
          { };
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

        devShells.default = pkgs.mkShell {
          packages = [
            ghcWithDeps
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

{
  description = "Lean 4 package";

  inputs = {
    nixpkgs.follows = "lean4-nix/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    lean4-nix.url = "github:lenianiva/lean4-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      lean4-nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (lean4-nix.readToolchainFile ./lean-toolchain) ];
        };

        lake2nix = pkgs.callPackage lean4-nix.lake { };
        packageName = "lean_project";
        package = lake2nix.mkPackage {
          name = packageName;
          src = pkgs.lib.cleanSource ./.;
        };
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

        checks.default = package;

        devShells.default = pkgs.mkShell {
          packages = with pkgs.lean; [
            lean-all
          ];
        };
      }
    );
}

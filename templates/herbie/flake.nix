{
  description = "Herbie virtual environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-utils.follows = "flake-utils";
    };
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };
        in
        with pkgs;
        {
          # TODO: Figure out how to not even touch the local ~/.local/racket and install packages locally
          devShells.default = mkShell {
            buildInputs = [
              rust-bin.stable.latest.default
              rust-analyzer
              racket-minimal
              just
            ];
          };
        }
      );
}

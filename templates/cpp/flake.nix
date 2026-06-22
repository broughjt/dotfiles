{
  description = "C++ package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        packageName = "cpp-template";
        src = pkgs.lib.cleanSource ./.;

        package = pkgs.clangStdenv.mkDerivation {
          pname = packageName;
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = with pkgs; [
            cmake
          ];

          cmakeFlags = [
            "-DCMAKE_BUILD_TYPE=Release"
          ];

          meta.mainProgram = packageName;
        };

        formatCheck =
          pkgs.runCommand "${packageName}-format-check" { nativeBuildInputs = [ pkgs.clang-tools ]; }
            ''
              ${pkgs.findutils}/bin/find ${src}/src -type f \
                \( -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' -o -name '*.h' -o -name '*.hh' -o -name '*.hpp' -o -name '*.hxx' \) \
                -exec clang-format --dry-run --Werror {} +
              touch "$out"
            '';
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

        checks = {
          default = package;
          format = formatCheck;
        };

        devShells.default = pkgs.mkShell.override { stdenv = pkgs.clangStdenv; } {
          inputsFrom = [ package ];

          packages = with pkgs; [
            clang-tools
            cmake
            gdb
            gnumake
            lldb
            pkg-config
          ];
        };
      }
    );
}

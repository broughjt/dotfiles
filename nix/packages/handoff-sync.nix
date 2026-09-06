{ pkgs }:

# Lives apart from scripts.nix so a Home Manager profile can install it with
# callPackage; scripts.nix needs flake inputs a home module cannot see.
pkgs.writeShellApplication {
  name = "handoff-sync";
  runtimeInputs = with pkgs; [
    coreutils
    diffutils
    git
    openssh
    rsync
  ];
  text = builtins.readFile ../../scripts/handoff-sync.sh;
}

{
  nix-darwin,
  home-manager,
  nix-config,
  emacsOverlays,
  nixosModules,
}:

nix-darwin.lib.darwinSystem {
  modules = [
    home-manager.darwinModules.home-manager
    (
      { lib, pkgs, ... }:
      {
        nix.settings = nix-config.nixSettings // {
          ssl-cert-file = "/etc/nix/macos-keychain.crt";
        };
        nixpkgs = {
          hostPlatform = "aarch64-darwin";
          config = nix-config.nixpkgsConfig;
          overlays = emacsOverlays;
        };

        system.stateVersion = 6;

        networking.hostName = "s1111508";

        programs.fish.enable = true;
        environment.shells = [ pkgs.fish ];
        users.users.jtbroug.home = "/Users/jtbroug";

        # Keep the existing admin user out of nix-darwin's managed users list,
        # but still declaratively point macOS at the Nix-managed fish shell.
        system.activationScripts.setJtbrougLoginShell.text = ''
          desired_shell=${lib.escapeShellArg "/run/current-system/sw/bin/fish"}
          current_shell=$(/usr/bin/dscl . -read /Users/jtbroug UserShell 2>/dev/null | /usr/bin/sed 's/^UserShell: //')

          if [ "$current_shell" != "$desired_shell" ]; then
            echo "setting jtbroug login shell to $desired_shell" >&2
            /usr/bin/dscl . -create /Users/jtbroug UserShell "$desired_shell"
          fi
        '';

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.jtbroug.imports = with nixosModules; [
            personal
            homeDirectories
            homeFish
            homeGit
            emacsHome
            homeDarwin
          ];
        };
      }
    )
  ];
}

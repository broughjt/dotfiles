{
  nix-darwin,
  home-manager,
  nix-config,
  llmAgentsOverlay,
  emacsOverlays,
  nixosModules,
}:

nix-darwin.lib.darwinSystem {
  modules = [
    home-manager.darwinModules.home-manager
    {
      nix.settings = nix-config.nixSettings // {
        ssl-cert-file = "/etc/nix/macos-keychain.crt";
      };
      nixpkgs = {
        hostPlatform = "aarch64-darwin";
        config = nix-config.nixpkgsConfig;
        overlays = [ llmAgentsOverlay ] ++ emacsOverlays;
      };

      system.stateVersion = 6;

      users.users.jtbroug.home = "/Users/jtbroug";

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
  ];
}

{ pkgs, scriptPackages }:

{
  devShells.default = pkgs.mkShell {
    packages =
      (with pkgs; [
        nil
        nixfmt
      ])
      ++ (with scriptPackages; [
        backupMurphSecrets
        restoreMurphSecrets
        spriteProvision
      ])
      ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux (
        with scriptPackages;
        [
          flashNixosInstaller
          installMurph
        ]
      );
  };
}

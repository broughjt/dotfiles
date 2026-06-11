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
        piPrintSystemPrompt
        restoreMurphSecrets
      ])
      ++ pkgs.lib.optionals pkgs.stdenv.isLinux (
        with scriptPackages;
        [
          flashNixosInstaller
          installMurph
        ]
      );
  };
}

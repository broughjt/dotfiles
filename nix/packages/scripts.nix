{
  pkgs,
  self,
  disko,
  home-manager,
  system,
}:

let
  dotfilesRevision = self.rev or self.dirtyRev or "unknown";
  dotfilesNarHash = self.narHash or "unknown";

  flashNixosInstaller = pkgs.writeShellApplication {
    name = "flash-nixos-installer";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      util-linux
    ];
    text = builtins.readFile ../../scripts/flash-nixos-installer.sh;
  };
  # disko still reads the deprecated stdenv.isDarwin alias. Keep the
  # compatibility value scoped to its package until upstream migrates.
  diskoInstall = disko.packages.${system}.disko-install.override {
    stdenv = pkgs.stdenv // {
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    };
  };
  installMurph = pkgs.writeShellApplication {
    name = "install-murph";
    runtimeInputs = with pkgs; [
      coreutils
      diskoInstall
      kmod
      mkpasswd
      procps
      util-linux
      zfs
    ];
    text = builtins.replaceStrings [ "@DOTFILES_FLAKE@" ] [ "${self}" ] (
      builtins.readFile ../../scripts/install-murph.sh
    );
  };
  backupMurphSecrets = pkgs.writeShellApplication {
    name = "backup-murph-secrets";
    runtimeInputs = with pkgs; [
      age
      coreutils
      gnutar
      gzip
      python3
    ];
    text = ''
      export MURPH_DOTFILES_REVISION=${pkgs.lib.escapeShellArg dotfilesRevision}
      export MURPH_DOTFILES_NAR_HASH=${pkgs.lib.escapeShellArg dotfilesNarHash}
      exec python3 ${../../scripts/backup_murph_secrets.py} "$@"
    '';
  };
  restoreMurphSecrets = pkgs.writeShellApplication {
    name = "restore-murph-secrets";
    runtimeInputs = with pkgs; [
      age
      coreutils
      gnutar
      gzip
      python3
    ];
    text = ''
      exec python3 ${../../scripts/restore_murph_secrets.py} "$@"
    '';
  };
  spriteProvision = pkgs.writeShellApplication {
    name = "sprite-provision";
    # coreutils covers the driver, which is all that runs here. The in-sprite
    # half travels as a plain file rather than a
    # writeShellApplication, so nothing prepends murph store paths to its PATH;
    # curl, sudo and the rest resolve against the sprite's own.
    #
    # sprite is deliberately absent: writeShellApplication prepends to PATH
    # rather than replacing it, so leaving it out is what lets murph's wrapped
    # sprite -- which carries the private HOME from home/sprite.nix -- be the
    # one that runs.
    runtimeInputs = [ pkgs.coreutils ];
    text =
      builtins.replaceStrings
        [ "@IN_SPRITE_SCRIPT@" ]
        [ "${../../scripts/sprite-provision-in-sprite.sh}" ]
        (builtins.readFile ../../scripts/sprite-provision.sh);
  };
  spriteHomeSwitch = pkgs.writeShellApplication {
    name = "sprite-home-switch";
    runtimeInputs = [
      pkgs.coreutils
      home-manager.packages.${system}.home-manager
    ];
    # ${self} is the exact source revision from which this app was evaluated.
    # A remote `nix run` therefore switches to the same pushed revision that
    # supplied the pinned Home Manager CLI, modules, and flake.lock.
    text = ''
      export USER="''${USER:-$(id -un)}"
      exec home-manager switch --flake ${pkgs.lib.escapeShellArg "${self}#sprite"} "$@"
    '';
  };
in
{
  inherit
    backupMurphSecrets
    flashNixosInstaller
    installMurph
    restoreMurphSecrets
    spriteHomeSwitch
    spriteProvision
    ;
}

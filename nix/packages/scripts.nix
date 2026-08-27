{
  pkgs,
  self,
  disko,
  system,
}:

let
  dotfilesRevision = self.rev or self.dirtyRev or "unknown";
  dotfilesNarHash = self.narHash or "unknown";

  piPrintSystemPrompt = pkgs.writeShellApplication {
    name = "pi-print-system-prompt";
    runtimeInputs = [ pkgs.bun ];
    text = ''
      export PI_CODING_AGENT_ROOT="${pkgs.llm-agents.pi}/lib/node_modules/@earendil-works/pi-coding-agent"
      exec bun ${../../scripts/pi-print-system-prompt.ts} "$@"
    '';
  };
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
    # coreutils covers the driver half, which runs here and needs only cat for
    # usage. The rest of the script runs inside the sprite against its own
    # fixed PATH, where these store paths do not exist, so curl, sudo and the
    # others it calls there are Ubuntu's and cannot be supplied from here.
    #
    # sprite is deliberately absent: writeShellApplication prepends to PATH
    # rather than replacing it, so leaving it out is what lets murph's wrapped
    # sprite -- which carries the private HOME from home/sprite.nix -- be the
    # one that runs.
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ../../scripts/sprite-provision.sh;
  };
in
{
  inherit
    backupMurphSecrets
    flashNixosInstaller
    installMurph
    piPrintSystemPrompt
    restoreMurphSecrets
    spriteProvision
    ;
}

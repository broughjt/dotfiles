{
  pkgs,
  self,
  disko,
  system,
}:

let
  agentInstructions = import ./agent-instructions.nix;

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
  # Everything sprite-provision installs into a sprite, plus the script that
  # installs it. Built here so the in-sprite half copies files rather than
  # carrying their content in its own text, and so the sprite's agent
  # instructions come out of the same assembler as murph's.
  spriteProvisionPayload = pkgs.runCommand "sprite-provision-payload" { } ''
    mkdir -p "$out/files"
    cp ${../../scripts/sprite-provision-in-sprite.sh} "$out/in-sprite.sh"
    cp ${
      agentInstructions.assembleAgentInstructions {
        inherit pkgs;
        machine = ../../agents/machines/sprite.md;
      }
    } "$out/files/agent-instructions.md"
    cp ${../../agents/machines/upstream/codex-agents.md} "$out/files/upstream-codex-agents.md"
  '';
  spriteProvision = pkgs.writeShellApplication {
    name = "sprite-provision";
    # coreutils covers the driver, which is all that runs here. The in-sprite
    # half travels in the payload as a plain file rather than a
    # writeShellApplication, so nothing prepends murph store paths to its PATH;
    # curl, sudo and the rest resolve against the sprite's own.
    #
    # sprite is deliberately absent: writeShellApplication prepends to PATH
    # rather than replacing it, so leaving it out is what lets murph's wrapped
    # sprite -- which carries the private HOME from home/sprite.nix -- be the
    # one that runs.
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.replaceStrings [ "@PAYLOAD@" ] [ "${spriteProvisionPayload}" ] (
      builtins.readFile ../../scripts/sprite-provision.sh
    );
  };
in
{
  inherit
    backupMurphSecrets
    flashNixosInstaller
    installMurph
    restoreMurphSecrets
    spriteProvision
    ;
}

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
  installMurph = pkgs.writeShellApplication {
    name = "install-murph";
    runtimeInputs = with pkgs; [
      coreutils
      disko.packages.${system}.disko-install
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
in
{
  inherit
    backupMurphSecrets
    flashNixosInstaller
    installMurph
    piPrintSystemPrompt
    restoreMurphSecrets
    ;
}

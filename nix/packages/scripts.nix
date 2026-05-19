{
  pkgs,
  self,
  disko,
  system,
}:

let
  piPrintSystemPrompt = pkgs.writeShellApplication {
    name = "pi-print-system-prompt";
    runtimeInputs = [ pkgs.bun ];
    text = ''
      export PI_CODING_AGENT_ROOT="${pkgs.llm-agents.pi}/lib/node_modules/@earendil-works/pi-coding-agent"
      exec bun ${../../scripts/pi-print-system-prompt.ts} "$@"
    '';
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
  backupMurph = pkgs.writeShellApplication {
    name = "backup-murph";
    runtimeInputs = with pkgs; [
      age
      coreutils
      git
      gnutar
      gzip
      python3
    ];
    text = ''
      exec python3 ${../../scripts/backup_murph.py} "$@"
    '';
  };
  restoreMurph = pkgs.writeShellApplication {
    name = "restore-murph";
    runtimeInputs = with pkgs; [
      age
      coreutils
      gnutar
      gzip
      python3
    ];
    text = ''
      exec python3 ${../../scripts/restore_murph.py} "$@"
    '';
  };
in
{
  inherit
    backupMurph
    installMurph
    piPrintSystemPrompt
    restoreMurph
    ;
}

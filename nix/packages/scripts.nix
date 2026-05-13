{
  pkgs,
  self,
  disko,
  system,
}:

let
  piPrintSystemPrompt = pkgs.writeShellApplication {
    name = "pi-print-system-prompt";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export PI_CODING_AGENT_ROOT="${pkgs.llm-agents.pi}/lib/node_modules/@earendil-works/pi-coding-agent"
      exec node ${../../scripts/pi-print-system-prompt.mjs} "$@"
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
  backupMurphSecrets = pkgs.writeShellApplication {
    name = "backup-murph-secrets";
    runtimeInputs = with pkgs; [
      age
      coreutils
      git
      gnutar
      gzip
    ];
    text = builtins.readFile ../../scripts/backup-murph-secrets.sh;
  };
  backupMurphConvenience = pkgs.writeShellApplication {
    name = "backup-murph-convenience";
    runtimeInputs = with pkgs; [
      coreutils
      git
      gnutar
      gzip
    ];
    text = builtins.readFile ../../scripts/backup-murph-convenience.sh;
  };
  restoreMurphSecrets = pkgs.writeShellApplication {
    name = "restore-murph-secrets";
    runtimeInputs = with pkgs; [
      age
      coreutils
      gnutar
      gzip
    ];
    text = builtins.readFile ../../scripts/restore-murph-secrets.sh;
  };
  restoreMurphConvenience = pkgs.writeShellApplication {
    name = "restore-murph-convenience";
    runtimeInputs = with pkgs; [
      coreutils
      gnutar
      gzip
    ];
    text = builtins.readFile ../../scripts/restore-murph-convenience.sh;
  };
in
{
  inherit
    backupMurphConvenience
    backupMurphSecrets
    installMurph
    piPrintSystemPrompt
    restoreMurphConvenience
    restoreMurphSecrets
    ;
}

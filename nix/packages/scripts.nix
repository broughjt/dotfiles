{
  pkgs,
  self,
  disko,
  nixos-anywhere,
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
  installCase = pkgs.writeShellApplication {
    name = "install-case";
    runtimeInputs = [
      nixos-anywhere.packages.${system}.default
    ]
    ++ (with pkgs; [
      coreutils
      hcloud
      openssh
      # No gnupg here on purpose. GnuPG configuration is the user's, and
      # nix/modules/home/gpg.nix wraps gpg with --homedir, --keyring and
      # --trustdb-name flags pointing at relocated paths. A bare gnupg ahead of
      # that wrapper on PATH reads an empty keyring and fails with "No secret
      # key". pass only appends its own gnupg as a fallback, so leaving it out
      # lets the user's wrapped gpg win.
      pass
      python3
    ]);
    text = builtins.replaceStrings [ "@DOTFILES_FLAKE@" ] [ "${self}" ] (
      builtins.readFile ../../scripts/install-case.sh
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
    installCase
    installMurph
    restoreMurphSecrets
    ;
}

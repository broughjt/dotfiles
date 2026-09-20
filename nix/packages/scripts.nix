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

  applyTailnetPolicy = pkgs.writeShellApplication {
    name = "apply-tailnet-policy";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      diffutils
      gnused
      jq
      # No gnupg here, for the reason installCase gives below.
      pass
    ];
    text = builtins.readFile ../../scripts/apply_tailnet_policy.sh;
  };
  handoffSync = pkgs.callPackage ./handoff-sync.nix { };
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
  installTars = pkgs.writeShellApplication {
    name = "install-tars";
    runtimeInputs = [
      nixos-anywhere.packages.${system}.default
    ]
    ++ (with pkgs; [
      coreutils
      # Hashes the generated console password; the plaintext never leaves pass.
      mkpasswd
      # nmcli --offline writes the Wi-Fi profiles, escaping them as
      # NetworkManager's keyfile format requires.
      networkmanager
      openssh
      # No gnupg, for the reason installCase gives above.
      pass
    ]);
    text = builtins.replaceStrings [ "@DOTFILES_FLAKE@" ] [ "${self}" ] (
      builtins.readFile ../../scripts/install-tars.sh
    );
  };
  flashTarsBootstrap = pkgs.writeShellApplication {
    name = "flash-tars-bootstrap";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      diffutils
      gnugrep
      jq
      # Hashes the generated console password; the plaintext never leaves pass.
      mkpasswd
      mtools
      # No gnupg, for the reason installCase gives above.
      pass
      util-linux
      xz
    ];
    text = builtins.replaceStrings [ "@DOTFILES_FLAKE@" ] [ "${self}" ] (
      builtins.readFile ../../scripts/flash-tars-bootstrap.sh
    );
  };
  flashTarsInstaller = pkgs.writeShellApplication {
    name = "flash-tars-installer";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      # debugfs writes the Wi-Fi profiles into the image's root partition.
      e2fsprogs
      gnugrep
      jq
      # nmcli --offline writes the Wi-Fi profiles, escaping them as
      # NetworkManager's keyfile format requires.
      networkmanager
      openssh
      # No gnupg, for the reason as installCase above.
      pass
      util-linux
      zstd
    ];
    text = builtins.replaceStrings [ "@DOTFILES_FLAKE@" ] [ "${self}" ] (
      builtins.readFile ../../scripts/flash-tars-installer.sh
    );
  };
  flashKippInstaller = pkgs.writeShellApplication {
    name = "flash-kipp-installer";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      # debugfs writes the Wi-Fi profiles into the image's root partition.
      e2fsprogs
      jq
      # nmcli --offline writes the Wi-Fi profiles, escaping them as
      # NetworkManager's keyfile format requires.
      networkmanager
      # No gnupg, for the reason installCase gives above.
      pass
      util-linux
    ];
    text = builtins.replaceStrings [ "@DOTFILES_FLAKE@" ] [ "${self}" ] (
      builtins.readFile ../../scripts/flash-kipp-installer.sh
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
    applyTailnetPolicy
    backupMurphSecrets
    flashNixosInstaller
    handoffSync
    installCase
    installMurph
    installTars
    flashKippInstaller
    flashTarsBootstrap
    flashTarsInstaller
    restoreMurphSecrets
    ;
}

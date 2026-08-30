{
  config,
  lib,
  pkgs,
  ...
}:

let
  codexEnvironment = {
    CODEX_HOME = config.codex.configDirectory;
    CODEX_SQLITE_HOME = config.codex.sqliteDirectory;
  };

  codexPackage = pkgs.callPackage ../../packages/codex.nix {
    codexHome = config.codex.configDirectory;
    sqliteHome = config.codex.sqliteDirectory;
    logDirectory = config.codex.logDirectory;
  };
in
{
  imports = [ ./agent-instructions.nix ];

  options.codex = {
    configDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.defaultDirectories.homeDirectory}/.codex";
      defaultText = lib.literalExpression ''"''${config.defaultDirectories.homeDirectory}/.codex"'';
      description = ''
        Directory Codex keeps configuration, credentials, history, sessions and
        user skills in, exported as `CODEX_HOME`. Defaults to {file}`~/.codex`,
        matching the upstream CLI.
      '';
    };

    sqliteDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.codex.configDirectory}/sqlite";
      defaultText = lib.literalExpression ''"''${config.codex.configDirectory}/sqlite"'';
      description = ''
        Directory for Codex's SQLite state, exported as `CODEX_SQLITE_HOME` and
        passed as `sqlite_home`.
      '';
    };

    logDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.codex.configDirectory}/log";
      defaultText = lib.literalExpression ''"''${config.codex.configDirectory}/log"'';
      description = ''
        Directory for Codex's logs, passed as `log_dir`.
      '';
    };
  };

  config = {
    home.packages = [ codexPackage ];
    home.sessionVariables = codexEnvironment;

    # Terminals launched from a graphical session inherit the systemd user
    # manager's environment rather than a login shell's, so the same values
    # have to reach environment.d.
    systemd.user.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux codexEnvironment;

    # Credentials, history and sessions live here, so these have to be private
    # before anything is written into them.
    home.activation.codexDirectories = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      run install -d -m 0700 ${
        lib.escapeShellArgs [
          config.codex.configDirectory
          config.codex.sqliteDirectory
          config.codex.logDirectory
        ]
      }
    '';

    home.file."${config.codex.configDirectory}/AGENTS.md".text = config.agentInstructions.text;
  };
}

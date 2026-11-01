{
  config,
  lib,
  pkgs,
  ...
}:

let
  codexPackage = pkgs.callPackage ../../packages/codex.nix {
    codexHome = config.codex.configDirectory;
  };
in
{
  imports = [
    ./agent-instructions.nix
  ];

  options.codex = {
    configDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.defaultDirectories.homeDirectory}/.codex";
      defaultText = lib.literalExpression ''"''${config.defaultDirectories.homeDirectory}/.codex"'';
      description = ''
        Directory Codex keeps configuration, credentials, history, sessions and
        user skills in, exported as `CODEX_HOME` by the wrapper. Defaults to
        {file}`~/.codex`, matching the upstream CLI.
      '';
    };
  };

  config = {
    home.packages = [ codexPackage ];

    # Credentials, history and sessions live here, so this has to be private
    # before anything is written into it.
    home.activation.codexDirectories = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      run install -d -m 0700 ${lib.escapeShellArg config.codex.configDirectory}
    '';

    home.file = lib.mkMerge (
      [ { "${config.codex.configDirectory}/AGENTS.md".text = config.agentInstructions.text; } ]
      # Not home-manager's programs.codex, so the handoff module cannot add
      # its skills; a host importing this one has to import homeHandoff too.
      ++ lib.mapAttrsToList (name: source: {
        "${config.codex.configDirectory}/skills/${name}".source = source;
      }) config.programs.handoff.skills
    );
  };
}

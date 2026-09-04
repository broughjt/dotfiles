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

  skillsSource = builtins.path {
    name = "skills";
    path = ../../../agents/skills;
  };
  skillNames = builtins.attrNames (builtins.readDir skillsSource);
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
      ++ map (name: {
        "${config.codex.configDirectory}/skills/${name}".source = "${skillsSource}/${name}";
      }) skillNames
    );
  };
}

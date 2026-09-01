{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude-code;

  defaultConfigFile =
    if cfg.configDir == "${config.home.homeDirectory}/.claude" then
      "${config.home.homeDirectory}/.claude.json"
    else
      "${cfg.configDir}/.claude.json";
in
{
  imports = [ ./agent-instructions.nix ];

  options.claudeCode.configFile = lib.mkOption {
    type = lib.types.str;
    default = defaultConfigFile;
    defaultText = lib.literalMD "`.claude.json` beside or inside `configDir`";
    description = ''
      Claude Code's global state file. Mutable application state rather than
      configuration, so nothing renders it; it is named here because other
      modules have to find it.
    '';
  };

  config = {
    programs.claude-code = {
      enable = true;
      package = pkgs.callPackage ../../packages/claude-code.nix { };

      context = config.agentInstructions.text;

      skills = builtins.path {
        name = "skills";
        path = ../../../agents/skills;
      };
    };
  };
}

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

  options.claudeCode.oauthTokenFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/home/jackson/.claude/oauth-token";
    description = ''
      Path to a file holding a token from `claude setup-token`, exported as
      CLAUDE_CODE_OAUTH_TOKEN by the claude wrapper. Useful on headless hosts.
      Null leaves Claude Code to its ordinary authentication.
    '';
  };

  config = {
    programs.claude-code = {
      enable = true;
      package = pkgs.callPackage ../../packages/claude-code.nix {
        inherit (config.claudeCode) oauthTokenFile;
      };

      context = config.agentInstructions.text;

      skills = builtins.path {
        name = "skills";
        path = ../../../agents/skills;
      };
    };

    home.activation = lib.mkIf (config.claudeCode.oauthTokenFile != null) {
      claudeCodeFirstRun = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        seedWhenAbsent() {
          if [ ! -e "$1" ]; then
            run install -m 0600 /dev/stdin "$1" <<<"$2"
          fi
        }

        seedWhenAbsent ${lib.escapeShellArg config.claudeCode.configFile} \
          '{"hasCompletedOnboarding":true}'
        seedWhenAbsent ${lib.escapeShellArg "${cfg.configDir}/settings.json"} \
          '{"theme":"auto","skipDangerousModePermissionPrompt":true}'
      '';
    };
  };
}

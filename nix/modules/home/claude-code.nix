{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./agent-instructions.nix ];

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
  };
}

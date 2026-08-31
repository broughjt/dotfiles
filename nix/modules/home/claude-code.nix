{ config, pkgs, ... }:

{
  imports = [ ./agent-instructions.nix ];

  programs.claude-code = {
    enable = true;
    package = pkgs.callPackage ../../packages/claude-code.nix { };

    context = config.agentInstructions.text;

    skills = builtins.path {
      name = "skills";
      path = ../../../agents/skills;
    };

    # The Claude Code harness rewrites settings.json in full whenever a setting
    # is modified, so using a declarative config makes Home Manager refuse to
    # switch to avoid overwritting a file it does not own. This refusal gives us
    # an idea of when Claude Code configuration options have changed.
    #
    # Make sure to check the schema before making updates:
    # https://json.schemastore.org/claude-code-settings.json
    settings = {
      attribution = {
        commit = "";
        pr = "";
        sessionUrl = false;
      };

      theme = "auto";
      model = "opus";
      autoMemoryEnabled = true;
      agentPushNotifEnabled = true;

      # Records that the bypass permissions dialog was accepted. Normally the
      # CLI writes this itself; declaring it pre-accepts on a fresh machine.
      skipDangerousModePermissionPrompt = true;

      voice.enabled = false;
    };
  };
}

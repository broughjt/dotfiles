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
  };
}

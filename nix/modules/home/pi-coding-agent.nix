{
  piWebAccessPackage,
  piWebMinimalPackage,
  piSystemPromptPackage,
}:

{ config, pkgs, ... }:

let
  piWebAccess = piWebAccessPackage pkgs;
  piWebMinimal = piWebMinimalPackage pkgs;
  piSystemPrompt = piSystemPromptPackage pkgs;
in
{
  home-manager.users.${config.personal.userName} = {
    home.file.".pi/agent/AGENTS.md" = {
      source = ../../../pi/AGENTS.md;
      force = true;
    };

    home.file.".pi/agent/bin/npm-nix" = {
      executable = true;
      force = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.pi/agent/npm-global}"
        mkdir -p "$NPM_CONFIG_PREFIX"
        exec ${pkgs.nodejs}/bin/npm "$@"
      '';
    };

    home.file.".pi/agent/settings.json" = {
      force = true;
      text = builtins.toJSON {
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.5";
        defaultThinkingLevel = "high";
        enableInstallTelemetry = false;
        npmCommand = [ "${config.defaultDirectories.homeDirectory}/.pi/agent/bin/npm-nix" ];
        packages = [
          # {
          #   source = "${piWebAccess}";
          #   extensions = [];
          #   skills = [];
          # }
          "${piWebMinimal}"
        ];
      };
    };
  };
}

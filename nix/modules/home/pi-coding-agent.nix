{
  config,
  lib,
  pkgs,
  ...
}:

let
  # A wrapper rather than the module's session variable, so Pi finds its
  # persisted directory however it is started.
  package = pkgs.symlinkJoin {
    name = "pi-${pkgs.llm-agents.pi.version}";
    paths = [ pkgs.llm-agents.pi ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --set PI_CODING_AGENT_DIR ${lib.escapeShellArg config.programs.pi-coding-agent.configDir} \
        --suffix PATH : ${lib.makeBinPath [ pkgs.python3 ]}
    '';
    inherit (pkgs.llm-agents.pi) meta;
  };
in
{
  imports = [
    ./agent-instructions.nix
  ];

  programs.pi-coding-agent = {
    enable = true;
    inherit package;
    context = config.agentInstructions.text;
    # Pi writes settings.json itself, for example when /model changes the default.
    mutableSettings = true;
    settings = {
      defaultProvider = "openai-codex";
      enableInstallTelemetry = false;
    };
  };
}

{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./agent-instructions.nix
  ];

  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.llm-agents.pi;
    extraPackages = [ pkgs.python3 ];
    context = config.agentInstructions.text;
    # Pi writes settings.json itself, for example when /model changes the default.
    mutableSettings = true;
    settings = {
      defaultProvider = "openai-codex";
      enableInstallTelemetry = false;
    };
  };
}

{ config, ... }:

{
  home.persistence.main.directories = [
    {
      directory = "local/state/claude-code";
      mode = "0700";
    }
  ];

  programs.claude-code.configDir = "${config.defaultDirectories.localDirectory}/state/claude-code";
}

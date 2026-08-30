{ config, ... }:

{
  home.persistence.main.directories = [
    {
      directory = "local/state/codex";
      mode = "0700";
    }
  ];

  codex.configDirectory = "${config.defaultDirectories.localDirectory}/state/codex";
}

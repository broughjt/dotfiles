{ ... }:

{
  home.persistence.main.directories = [
    {
      directory = "local/config/mozilla/firefox";
      mode = "0700";
    }
  ];

  programs.firefox.configPath = "local/config/mozilla/firefox";
}

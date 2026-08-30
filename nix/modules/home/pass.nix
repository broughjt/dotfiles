{ config, ... }:

{
  programs.password-store = {
    enable = true;
    settings = {
      PASSWORD_STORE_DIR = "${config.defaultDirectories.repositoriesDirectory}/passwords";
    };
  };
}

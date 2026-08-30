{
  config,
  ...
}:

let
  user = config.personal.userName;
in
{
  home-manager.users.${user} = {
    programs.ghostty = {
      enable = true;
      settings = {
        theme = "dark:3024 Night,light:3024 Day";
        font-family = "JuliaMono";
      };
    };
  };
}

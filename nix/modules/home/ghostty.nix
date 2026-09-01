{ ... }:

{
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "dark:3024 Night,light:3024 Day";
      font-family = "JuliaMono";
      # Comes in clutch if you forgot to add `tee`
      keybind = [
        "ctrl+shift+j=write_scrollback_file:open"
      ];
    };
  };
}

{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
  emacsHacksDirectory = config.emacs.hacksDirectory;
  emacsStateDirectory = "${config.xdg.stateHome}/emacs";
in
{
  # The known-projects list, plus the Racket REPL history and its editable
  # scratch file. Other Emacs state (eln-cache, auto-save-list, transient,
  # custom, bookmarks) is intentionally ephemeral under ~/local/{cache,state}.
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath "${emacsHacksDirectory}/projects";
      mode = "0700";
    }
    {
      directory = toHomeRelativePath "${emacsHacksDirectory}/racket-mode";
      mode = "0700";
    }
    {
      directory = toHomeRelativePath "${emacsStateDirectory}/backups";
      mode = "0700";
    }
    {
      directory = toHomeRelativePath "${emacsStateDirectory}/auto-saves";
      mode = "0700";
    }
  ];

  emacs.hacksDirectory = "${config.defaultDirectories.localDirectory}/hacks/emacs";
}

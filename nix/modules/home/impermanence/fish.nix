{ ... }:

{
  # Fish rewrites history via temporary files and rename, so the persisted
  # entry is the containing directory rather than fish_history itself. The
  # symlink pointing fish at it still lives in murph-user-state.nix.
  home.persistence.main.directories = [
    {
      directory = "local/hacks/fish/fish_history";
      mode = "0700";
    }
  ];
}

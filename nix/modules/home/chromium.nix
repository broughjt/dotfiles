{ ... }:

{
  programs.chromium = {
    enable = true;
    commandLineArgs = [ "--no-first-run" ];
  };
}

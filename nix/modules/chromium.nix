{ config, ... }:

{
  programs.chromium = {
    enable = true;
    extraOpts = {
      # Get Chromium to respect `scratchDirectory` as the downloads directory

      DownloadDirectory = config.defaultDirectories.scratchDirectory;
      # Save straight to that directory. A save dialog stalls the download
      # until someone is at the machine to answer it, which defeats starting a
      # long transfer and walking away.
      PromptForDownloadLocation = false;
    };
  };
}

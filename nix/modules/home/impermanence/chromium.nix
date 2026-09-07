{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  home.persistence.main.directories = [
    # The Chromium profile contains cookies, logins, extension state, local
    # storage, history, and preferences. It also co-locates rebuildable data,
    # which is intentionally retained rather than split out again. Chromium's
    # separate XDG cache directory remains ephemeral.
    {
      directory = toHomeRelativePath "${config.xdg.configHome}/chromium";
      mode = "0700";
    }
    # The shared NSS database used by Chromium and Firefox contains local
    # certificate trust decisions and imported client certificates.
    {
      directory = toHomeRelativePath "${config.xdg.dataHome}/pki/nssdb";
      mode = "0700";
    }
  ];
}

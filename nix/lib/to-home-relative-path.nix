{ config, lib }:

path:

let
  homeDirectoryPrefix = "${config.home.homeDirectory}/";
  pathString = toString path;
in
# Home Manager's file and impermanence APIs expect home-relative paths, while
# silently accepting some wrong absolute ones. Reject paths outside the home.
if lib.hasPrefix "/" pathString then
  assert lib.assertMsg (lib.hasPrefix homeDirectoryPrefix pathString) (
    "home path ${pathString} is outside ${config.home.homeDirectory}"
  );
  lib.removePrefix homeDirectoryPrefix pathString
else
  pathString

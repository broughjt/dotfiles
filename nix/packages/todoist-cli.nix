{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:

buildNpmPackage rec {
  pname = "todoist-cli";
  version = "1.75.0";

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    tag = "v${version}";
    hash = "sha256-3cDeYepZTS0vQRK6eUcrHvZE3vC1hOe/by8yrEIiAvo=";
  };

  npmDepsHash = "sha256-IcDuSeMM8wmp3fvO+4YWP5DIHonp9P8U/49Tp76pnqU=";

  inherit nodejs;

  meta = {
    description = "Command-line interface for Todoist";
    homepage = "https://github.com/Doist/todoist-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "td";
  };
}

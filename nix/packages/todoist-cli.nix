{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:

buildNpmPackage rec {
  pname = "todoist-cli";
  version = "1.68.0";

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    tag = "v${version}";
    hash = "sha256-jcxECkVlMfH6PtvNkJYoWAybCvX7m6rdO71w1ixRlEg=";
  };

  npmDepsHash = "sha256-71za66XKLTqVIYjQw+JXsb6iIZqzNpSDRhxJ04BMoSY=";

  inherit nodejs;

  meta = {
    description = "Command-line interface for Todoist";
    homepage = "https://github.com/Doist/todoist-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "td";
  };
}

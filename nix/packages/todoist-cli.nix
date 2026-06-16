{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:

buildNpmPackage rec {
  pname = "todoist-cli";
  version = "1.74.0";

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    tag = "v${version}";
    hash = "sha256-rPgTYZqqecOE3eVw9qJBLESNF7DMbR7E9cezHFmKeZs=";
  };

  npmDepsHash = "sha256-BW238pzFc7Cwt5lfnR5xAtSv87qE/4ge88h3ynjzVI0=";

  inherit nodejs;

  meta = {
    description = "Command-line interface for Todoist";
    homepage = "https://github.com/Doist/todoist-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "td";
  };
}

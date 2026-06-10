{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:

buildNpmPackage rec {
  pname = "todoist-cli";
  version = "1.73.1";

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    tag = "v${version}";
    hash = "sha256-SVGOiyucHL4+twlVEKqaPaIonuraKqXH7FHZqvGCngE=";
  };

  npmDepsHash = "sha256-JCypTGZlpnOCboqBqPyxvq4bHBadBNaPMe91+2tMc58=";

  inherit nodejs;

  meta = {
    description = "Command-line interface for Todoist";
    homepage = "https://github.com/Doist/todoist-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "td";
  };
}

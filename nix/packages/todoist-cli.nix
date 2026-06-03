{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:

buildNpmPackage rec {
  pname = "todoist-cli";
  version = "1.72.0";

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    tag = "v${version}";
    hash = "sha256-dMILcdeLWH7Hoj2omIsW43091UzCfwVbkRACJcKhLz8=";
  };

  npmDepsHash = "sha256-pk9r6g32lt76gDrR/HHnFxVCVn9lguRwa0RjHjoAEOE=";

  inherit nodejs;

  meta = {
    description = "Command-line interface for Todoist";
    homepage = "https://github.com/Doist/todoist-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "td";
  };
}

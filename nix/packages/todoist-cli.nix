{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:

buildNpmPackage rec {
  pname = "todoist-cli";
  version = "1.73.4";

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    tag = "v${version}";
    hash = "sha256-2oAHVz1cMYEcL81eT5mNqdWjjr5y24n5xQGN4rkFp9E=";
  };

  npmDepsHash = "sha256-WkgVPDbeOVI5+X4OWPxg7fSAi+4hzHrho59dZM3h/Y0=";

  inherit nodejs;

  meta = {
    description = "Command-line interface for Todoist";
    homepage = "https://github.com/Doist/todoist-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "td";
  };
}

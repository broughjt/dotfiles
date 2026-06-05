{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:

buildNpmPackage rec {
  pname = "todoist-cli";
  version = "1.72.1";

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    tag = "v${version}";
    hash = "sha256-MALH7axWJ9ZeIg8yvswMdp9ox3pfQTzG8PGLsKtfTVU=";
  };

  npmDepsHash = "sha256-Br0Ji2YGu5ttOgY9IiFClwaDa7jSpBMlgALWZDK1Lmg=";

  inherit nodejs;

  meta = {
    description = "Command-line interface for Todoist";
    homepage = "https://github.com/Doist/todoist-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "td";
  };
}

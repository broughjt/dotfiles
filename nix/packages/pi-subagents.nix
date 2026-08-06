pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-subagents";
  version = "0.41.0";

  src = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-subagents";
    rev = "92e3a42b1148814133668f7509ec4ef9c0ab825d";
    hash = "sha256-fsXEYKRPMYmZ3gMlqXO21ufI0Eqc/fS7ybLx4/7GGk8=";
  };

  npmDepsHash = "sha256-6RCPcMlrLcHQ7eH+hWrI9Q2KwCAJlBZJlyDbqwQb9d0=";
  postPatch = ''
    cp ${../../pi/pi-subagents-package-lock.json} package-lock.json
  '';
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r \
      install.mjs \
      package.json \
      README.md \
      CHANGELOG.md \
      banner.png \
      agents \
      prompts \
      skills \
      src \
      node_modules \
      $out/
    runHook postInstall
  '';
}

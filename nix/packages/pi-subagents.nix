pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-subagents";
  version = "0.35.1";

  src = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-subagents";
    rev = "d6e8005e3958adea634bf27c615abac7407aedc4";
    hash = "sha256-EQh9bfQROqWkpqqdSgXNebnUHF3nP8syvNlUyl7G4jM=";
  };

  npmDepsHash = "sha256-aQXrEqZ26ylZxCc+1w7yw1c+zLbXzvmUGKHuhrXXkTM=";
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

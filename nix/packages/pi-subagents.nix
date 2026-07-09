pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-subagents";
  version = "0.34.0";

  src = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-subagents";
    rev = "12a157d2a70b2f4cbc004c020c5f9213b6d8eea8";
    hash = "sha256-RN8f5cT/oRSkqwOAmvJ2uJsOmScYb0ijwixTd75iGHk=";
  };

  npmDepsHash = "sha256-IJJ3hceNvHUr5QFIa/+0tnxNiEPh7jifE9dvPHrLE58=";
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

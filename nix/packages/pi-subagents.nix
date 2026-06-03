pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-subagents";
  version = "0.28.0";

  src = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-subagents";
    rev = "ff6f6c1dc83adca657b6f21c4e78718d24b71147";
    hash = "sha256-GsEV55Yv5gG+bZiqrPAzFClMwRSjbLxSYpDfT5eF/nA=";
  };

  npmDepsHash = "sha256-nYsOATRaDnK+6n4J04C2jluGxKGZy4AIkSHEXh5G9z0=";
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

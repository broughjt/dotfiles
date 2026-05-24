pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-subagents";
  version = "0.25.0";

  src = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-subagents";
    rev = "86326d731b106a85c2b3ec52779e442e1ba3bdd9";
    hash = "sha256-MLQ7/+xEd2xTI37rMfWaYP7I724MWN+pgXhv78OxjL8=";
  };

  npmDepsHash = "sha256-GXNsoy8zWgq5oUMwXst+RrNJdor+010pzOXmVWXWfBA=";
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

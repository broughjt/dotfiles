pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-subagents";
  version = "0.40.0";

  src = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-subagents";
    rev = "d4d2ab706b612ccd173caad2bc202eef07e7eda3";
    hash = "sha256-LNm4h9OxoljQNXZKmg+P3MUHEWDO6H2x0qMx/gHQwkY=";
  };

  npmDepsHash = "sha256-ilCmbu7iAcg7oRcIgfs3jepsLV6HP0fI8nYsIjxjsAw=";
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

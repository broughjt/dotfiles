pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-subagents";
  version = "0.37.0";

  src = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-subagents";
    rev = "53945b578d8d4f2365dcb2f11c817f874fc91977";
    hash = "sha256-pmJ8AWw/QshcvLxS57kd261wccLpb/IEXDrKdZ48kck=";
  };

  npmDepsHash = "sha256-jSFKW6vuyI6X4ipfNxbk8NicbYj14U4qWuQuc95y2ro=";
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

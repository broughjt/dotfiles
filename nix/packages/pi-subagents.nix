pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-subagents";
  version = "0.31.1";

  src = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-subagents";
    rev = "47ca0bc002faf5122831e4eebd2bf68811749d95";
    hash = "sha256-wIeIsNqAyaMgKs3frf2FAObOho3OLFTsQcUShncK9Rc=";
  };

  npmDepsHash = "sha256-9m/qGjHxxIlp5VAI33DBSlooTBBwc4jy0ueKITz9jow=";
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

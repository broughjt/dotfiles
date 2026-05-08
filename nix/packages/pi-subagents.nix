pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-subagents";
  version = "0.7.1";

  src = pkgs.fetchFromGitHub {
    owner = "tintinweb";
    repo = "pi-subagents";
    rev = "08150d46d09d9c9f7008bb9b61b52a51f5c9eb8d";
    hash = "sha256-QGYRaIIwQB5WxXvLcOIIZY1laKtYPQFS71fzacK2Vlo=";
  };

  npmDepsHash = "sha256-6CZL3SnFm4AeAVhSOHylEPHLbbex7vsyEHbm6Ludxq0=";
  npmFlags = [ "--legacy-peer-deps" ];
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r package.json README.md LICENSE CHANGELOG.md src node_modules $out/
    runHook postInstall
  '';
}

pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-agent-browser-native";
  version = "0.2.77";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "128d7eb915fbb3b5e05720273aae6f6cc4349b9a";
    hash = "sha256-vtvx4S7hCBsZP8ZE4XsCPLyIfvF+y2/C6ZJWcNhKDlM=";
  };

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-bRsaUKcgx2Q5AS44aL+oiREg6G4hr01OH/S3OVrYq2E=";
  postPatch = ''
    cp ${../../pi/pi-agent-browser-native-package-lock.json} package-lock.json
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/scripts
    cp scripts/config.mjs scripts/doctor.mjs $out/scripts/
    cp -r \
      dist \
      platform-smoke.config.mjs \
      package.json \
      README.md \
      CHANGELOG.md \
      LICENSE \
      docs \
      $out/
    runHook postInstall
  '';
}

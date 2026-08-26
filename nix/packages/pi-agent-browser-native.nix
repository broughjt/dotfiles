pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-agent-browser-native";
  version = "0.5.1";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "33bcc5d749b3a000eea65ccb12b7e858246dab51";
    hash = "sha256-hUs0kn7wjiCwyGtisqqIGtXxjVj2tRkafu8dhFCdopQ=";
  };

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-QpGcZrL9udIFlIu1IKqypJTIEPEiyMyvcFkNRZYsUCA=";
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

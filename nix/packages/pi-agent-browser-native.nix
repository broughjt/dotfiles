pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-agent-browser-native";
  version = "0.2.65";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "5b274b6c3a0779a7e17aec0ae72e491b08572a56";
    hash = "sha256-fKPhQNGoXtJkdyP4JGzeVAG5YKdMISJPiiD4FFJFGhk=";
  };

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-ZcfWtQzGHpiz3snD001e5fPVb+tMoPdO032V8tsCFTU=";
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
